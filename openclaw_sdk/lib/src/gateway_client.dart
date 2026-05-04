// gateway_client.dart - Agent Event Handler

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';
import 'protocol.dart';
import 'exceptions.dart';

/// Send acknowledgment
class SendAck {
  final String messageId;
  final bool success;
  final String? error;

  SendAck({
    required this.messageId,
    required this.success,
    this.error,
  });
}

/// Queued message for offline/resend support
class _QueuedMessage {
  final String id;
  final String content;
  final DateTime queuedAt;
  int attempts;

  _QueuedMessage({
    required this.id,
    required this.content,
    required this.queuedAt,
    this.attempts = 0,
  });
}

class GatewayClient {
  final OpenClawConfig config;
  final Logger _logger;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<Message>.broadcast();
  final _taskStatusController = StreamController<TaskStatus>.broadcast();
  final _sendAckController = StreamController<SendAck>.broadcast();
  final _logController = StreamController<String>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  // Pending messages waiting for acknowledgment
  final Map<String, Completer<SendAck>> _pendingMessages = {};
  
  // Ping tracking for connection health
  int _pendingPings = 0;
  static const int _maxPendingPings = 3;
  
  // Message queue for offline/resend support
  final List<_QueuedMessage> _messageQueue = [];
  
  // Connection state
  bool _isConnecting = false;
  bool _intentionalDisconnect = false;
  
  // Auth state
  bool _authComplete = false;
  Completer<void>? _authCompleter;
  // If 3 pings fail, assume disconnected
  
  /// Stream of connection status changes
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Stream of incoming messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of task status updates
  Stream<TaskStatus> get taskStatusStream => _taskStatusController.stream;
  
  /// Stream of send acknowledgments
  Stream<SendAck> get sendAckStream => _sendAckController.stream;
  
  /// Stream of detailed logs (for debugging)
  Stream<String> get logStream => _logController.stream;

  void _log(String message, {String level = 'INFO'}) {
    final logMessage = '[$level] $message';
    _logger.i(logMessage);
    if (!_logController.isClosed) {
      _logController.add(logMessage);
    }
  }

  GatewayClient({
    required this.config,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  /// Current connection status
  ConnectionStatus get status => _status;
  
  /// Whether currently connected
  bool get isConnected => _status == ConnectionStatus.connected;

  /// Connect to Gateway
  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting ||
        _status == ConnectionStatus.connected) {
      _log('Already connecting or connected, skipping');
      return;
    }

    _isConnecting = true;
    _intentionalDisconnect = false;
    _authComplete = false;
    _updateStatus(ConnectionStatus.connecting);
    _log('🔌 Starting connection to Gateway: ${config.websocketUrl}');

    try {
      _log('🔌 Building WebSocket URL...');
      final wsUri = Uri.parse(config.websocketUrl);
      final authUri = wsUri.replace(
        queryParameters: {
          ...wsUri.queryParameters,
          'token': config.token,
        },
      );
      _log('🔌 WebSocket URL: $authUri');

      _log('🔌 Connecting to WebSocket...');
      final socket = await WebSocket.connect(authUri.toString()).timeout(
        Duration(seconds: config.timeoutSeconds),
        onTimeout: () {
          _log('❌ WebSocket connection timeout', level: 'ERROR');
          throw TimeoutException('WebSocket connection timeout');
        },
      );
      _log('✅ WebSocket connected');

      socket.pingInterval = const Duration(seconds: 30);
      _log('✅ Ping interval set to 30s');

      _channel = IOWebSocketChannel(socket);
      _log('✅ WebSocketChannel created');

      _subscription = _channel!.stream.listen(
        (data) {
          final preview = data.toString().length > 200 
              ? data.toString().substring(0, 200) 
              : data.toString();
          _log('📨 Received: $preview');
          _handleMessage(data);
        },
        onError: (error) {
          _log('❌ WebSocket error: $error', level: 'ERROR');
          _handleError(error);
        },
        onDone: () {
          _log('🔌 WebSocket closed by server');
          _handleDisconnect();
        },
      );
      _log('✅ Listening to WebSocket stream');

      _log('⏳ Waiting for authentication...');
      await _waitForAuth();

      _startHeartbeat();
      _log('✅ Heartbeat started');

      // 方向 2：订阅消息事件（模仿 Web 界面）
      _subscribeToEvents();

      _updateStatus(ConnectionStatus.connected);
      _reconnectAttempts = 0;
      _isConnecting = false;

      _log('🎉 Connected to Gateway successfully');
    } catch (e) {
      _log('❌ Failed to connect: $e', level: 'ERROR');
      _isConnecting = false;
      _updateStatus(ConnectionStatus.error);
      await _handleReconnect();
    }
  }

  /// 订阅消息事件（模仿 Web 界面）
  void _subscribeToEvents() {
    if (_channel == null) {
      _log('⚠️ Cannot subscribe: channel is null', level: 'WARN');
      return;
    }

    try {
      // 订阅 agent 和 chat 事件
      final subscribeRequest = {
        'type': 'req',
        'id': 'subscribe-${DateTime.now().millisecondsSinceEpoch}',
        'method': 'subscribe',
        'params': {
          'events': ['agent', 'chat', 'notification'],
        },
      };

      _channel!.sink.add(jsonEncode(subscribeRequest));
      _log('📡 Sent subscribe request for events: agent, chat, notification');
    } catch (e) {
      _log('❌ Failed to subscribe to events: $e', level: 'ERROR');
    }
  }

  /// Disconnect from Gateway
  Future<void> disconnect() async {
    _log('🔌 Disconnecting from Gateway');
    _intentionalDisconnect = true;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _subscription?.cancel();
    await _channel?.sink.close();

    _subscription = null;
    _channel = null;

    _updateStatus(ConnectionStatus.disconnected);
    _log('✅ Disconnected from Gateway');
  }

  /// Send message to Gateway with retry support
  Future<Message> sendMessage(String content, {Duration? timeout}) async {
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
    );

    _messageQueue.add(_QueuedMessage(
      id: message.id,
      content: content,
      queuedAt: DateTime.now(),
    ));

    const maxRetries = 5;
    var retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        // 强制重连，确保连接有效
        if (!isConnected || _channel == null) {
          _log('⚠️ Not connected, reconnecting...');
          await _forceDisconnect();
          await connect();
          await Future.delayed(const Duration(seconds: 2));
        }
        
        // 再次检查
        if (_channel == null) {
          throw ConnectionException('Channel is null after connect');
        }

        await _sendMessageInternal(message);
        
        _messageQueue.removeWhere((m) => m.id == message.id);
        _log('✅ Message ${message.id} sent successfully');
        return message;
        
      } catch (e) {
        retryCount++;
        _log('❌ Send attempt $retryCount failed: $e', level: 'ERROR');
        
        if (retryCount >= maxRetries) {
          // 保存消息到队列，等下次重连时重发
          _log('⚠️ Max retries reached, message queued for later');
          throw ConnectionException('Failed to send after $maxRetries attempts: $e');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _forceDisconnect();
      }
    }
    
    throw ConnectionException('Failed to send message');
  }

  /// Internal send (no retry, just send)
  Future<void> _sendMessageInternal(Message message) async {
    if (_channel == null) {
      throw ConnectionException('WebSocket is null');
    }

    final request = {
      'type': 'req',
      'id': message.id,
      'method': 'agent',
      'params': {
        'message': message.content,
        'idempotencyKey': message.id,
        // 不指定 sessionKey，使用默认 session（测试 Gateway 是否支持从 WebSocket 发送消息）
        'agentId': 'main',
        'clientName': 'control-ui',
        'mode': 'web',
      },
    };

    _log('📤 Sending message ${message.id}');
    _log('📤 Request: ${jsonEncode(request)}');
    
    _pendingMessages[message.id] = Completer<SendAck>();

    try {
      _channel!.sink.add(jsonEncode(request));
      _log('✅ Message sent to socket');

      // Gateway 可能不返回确认，所以只等待 10 秒
      // 如果超时，不抛出异常，只是记录警告
      try {
        final ack = await _pendingMessages[message.id]!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _log('⚠️ No ack after 10s (Gateway may not send ack)', level: 'WARN');
            // 返回一个成功的 ack，不阻塞消息发送
            return SendAck(messageId: message.id, success: true);
          },
        );
        
        if (!ack.success) {
          throw ConnectionException('Gateway rejected message: ${ack.error}');
        }
        
        _log('✅ Message ${message.id} acknowledged');
      } catch (e) {
        _log('⚠️ Ack wait error: $e (continuing anyway)', level: 'WARN');
        // 即使等待确认失败，也认为消息已发送
      }
    } finally {
      _pendingMessages.remove(message.id);
    }
  }

  /// Force disconnect (for retry)
  Future<void> _forceDisconnect() async {
    try {
      await _subscription?.cancel();
      await _channel?.sink.close();
    } catch (e) {
      _log('Force disconnect error: $e', level: 'ERROR');
    }
    _subscription = null;
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  void _startHeartbeat() {
    _pendingPings = 0;
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (isConnected && _channel != null) {
          _pendingPings++;
          
          if (_pendingPings > _maxPendingPings) {
            _log('Too many pending pings, connection likely dead', level: 'WARN');
            _handleDisconnect();
            return;
          }
          
          final ping = RpcProtocol.createRequest(method: RpcMethods.ping);
          try {
            _channel!.sink.add(ping);
            _log('Ping sent (pending: $_pendingPings)');
          } catch (e) {
            _log('Failed to send ping: $e', level: 'ERROR');
            _handleDisconnect();
          }
        }
      },
    );
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final preview = data.toString().length > 100 
          ? data.toString().substring(0, 100) 
          : data.toString();
      _log('📨 Message: $preview');
      _log('📨 Full message: ${jsonEncode(message)}');

      // Handle authentication
      if (message['type'] == 'event' && message['event'] == 'connect.challenge') {
        final payload = message['payload'] as Map<String, dynamic>;
        _handleChallenge(payload);
        return;
      }

      if (message['type'] == 'event' && message['event'] == 'connect.ready') {
        _log('✅ Received connect.ready event - authentication successful');
        _authComplete = true;
        _authCompleter?.complete();
        return;
      }

      if (message['type'] == 'res' && message['ok'] == true) {
        final payload = message['payload'] as Map<String, dynamic>?;
        if (payload?['type'] == 'hello-ok') {
          _log('✅ Received hello-ok response - authentication successful');
          _authComplete = true;
          _authCompleter?.complete();
          return;
        }
      }

      if (message['type'] == 'event' && message['event'] == 'connect.error') {
        _log('❌ Authentication failed: ${message['payload']}', level: 'ERROR');
        _authComplete = false;
        _authCompleter?.completeError(Exception('Authentication failed'));
        return;
      }
      
      if (message['type'] == 'res' && message['ok'] == false) {
        final error = message['error'];
        _log('❌ RPC error: $error', level: 'ERROR');
        if (message['id']?.toString().startsWith('connect') == true) {
          _authComplete = false;
          _authCompleter?.completeError(Exception('Connect failed'));
        }
        return;
      }

      // Handle RPC responses
      if (message['type'] == 'res' || message['jsonrpc'] != null) {
        _handleResponse(message);
        return;
      }

      // Handle events
      if (message['type'] == 'notification' || message['type'] == 'event') {
        _handleNotification(message);
      }

    } catch (e) {
      _log('Error handling message: $e', level: 'ERROR');
    }
  }

  void _handleChallenge(Map<String, dynamic> payload) {
    final nonce = payload['nonce'] as String;
    _log('🔑 Challenge nonce: $nonce');
    
    final connectRequest = {
      'type': 'req',
      'id': 'connect-${DateTime.now().millisecondsSinceEpoch}',
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': 'openclaw-android',
          'displayName': 'OpenClaw Mobile',
          'version': '1.0.0',
          'platform': 'android',
          'mode': 'ui',
        },
        'auth': {'token': config.token},
        'role': 'operator',
        'scopes': ['operator.admin'],
      },
    };

    _log('📤 Sending connect request');
    _channel!.sink.add(jsonEncode(connectRequest));
    _log('✅ Connect request sent');
  }

  void _handleAgentEvent(Map<String, dynamic> event) {
    _log('🎉 Agent event received!');
    final payload = event['payload'] as Map<String, dynamic>?;
    if (payload != null) {
      final data = payload['data'] as Map<String, dynamic>?;
      if (data != null) {
        final content = data['content'] as String? ?? '';
        final thinking = data['thinking'] as String?;
        
        _log('Content: $content');
        if (thinking != null) {
          _log('Thinking: $thinking');
        }
        
        final message = Message(
          id: data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: content,
          thinking: thinking,
          status: MessageStatus.complete,
        );
        if (!_messageController.isClosed) {
          _messageController.add(message);
          _log('✅ Agent message added to stream');
        }
      }
    }
  }

  void _handleNotification(Map<String, dynamic> notification) {
    final event = notification['event'] as String;
    final data = notification['data'] as Map<String, dynamic>? ?? 
                 notification['payload'] as Map<String, dynamic>? ?? {};

    _log('Received event: $event');

    switch (event) {
      case 'chat':
        final messageData = data['message'] as Map<String, dynamic>? ?? data;
        final message = Message(
          id: messageData['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          role: messageData['role'] as String? ?? 'assistant',
          content: messageData['content'] as String? ?? '',
          thinking: messageData['thinking'] as String?,
          status: MessageStatus.complete,
        );
        if (!_messageController.isClosed) {
          _messageController.add(message);
        }
        break;

      case 'agent':
        _handleAgentEvent(notification);
        break;

      case RpcEvents.messageReceived:
        final msg = Message.fromJson(data);
        if (!_messageController.isClosed) {
          _messageController.add(msg);
        }
        break;

      case RpcEvents.taskStarted:
      case RpcEvents.taskProgress:
      case RpcEvents.taskCompleted:
      case RpcEvents.taskFailed:
        final taskStatus = TaskStatus.fromJson(data);
        if (!_taskStatusController.isClosed) {
          _taskStatusController.add(taskStatus);
        }
        break;

      case RpcEvents.statusChanged:
        _log('Gateway status changed: $data');
        break;
    }
  }

  void _handleResponse(Map<String, dynamic> response) {
    final id = response['id'] as String?;
    final ok = response['ok'];
    _log('📥 Response for: $id, ok: $ok, full: ${jsonEncode(response)}');
    
    // Reset ping counter on any response
    _pendingPings = 0;
    
    // Check if this is a response to a pending message
    if (id != null && _pendingMessages.containsKey(id)) {
      final success = ok == true;
      final errorMsg = response['error']?['message'] as String?;
      _log('${success ? "✅" : "❌"} Completing pending message: $id, success: $success, error: $errorMsg');
      _pendingMessages[id]?.complete(SendAck(
        messageId: id,
        success: success,
        error: errorMsg,
      ));
      return;
    }
    
    // Also check if it's a generic success response (some Gateways return simple ok:true)
    if (ok == true && id != null && id.startsWith(RegExp(r'^\d{13}'))) {
      // Looks like a timestamp-based message ID
      _log('✅ Generic success response for message: $id');
      if (_pendingMessages.containsKey(id)) {
        _pendingMessages[id]?.complete(SendAck(
          messageId: id,
          success: true,
        ));
      }
    }
  }

  void _handleError(dynamic error) {
    _log('WebSocket error: $error', level: 'ERROR');
    _updateStatus(ConnectionStatus.error);
  }

  void _handleDisconnect() {
    if (_intentionalDisconnect) {
      return;
    }

    _log('Connection lost');
    _updateStatus(ConnectionStatus.disconnected);
    _handleReconnect();
  }

  Future<void> _handleReconnect() async {
    if (!config.autoReconnect) return;
    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _log('Max reconnect attempts reached', level: 'ERROR');
      return;
    }

    _reconnectAttempts++;
    _updateStatus(ConnectionStatus.reconnecting);

    final delay = _reconnectAttempts == 1 ? 1 : 
                  _reconnectAttempts == 2 ? 2 : 
                  _reconnectAttempts == 3 ? 4 : 
                  _reconnectAttempts == 4 ? 8 : 
                  _reconnectAttempts == 5 ? 16 : 30;

    _log('Reconnecting in ${delay}s (attempt $_reconnectAttempts/${config.maxReconnectAttempts})');

    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      await connect();
      _resendQueuedMessages();
    });
  }

  void _resendQueuedMessages() {
    if (_messageQueue.isEmpty) return;
    _log('Resending ${_messageQueue.length} queued messages');
    
    for (final queued in _messageQueue.toList()) {
      queued.attempts++;
      if (queued.attempts > 5) {
        _log('Dropping message after 5 failed attempts: ${queued.id}', level: 'WARN');
        _messageQueue.remove(queued);
        continue;
      }
      
      final message = Message(
        id: queued.id,
        role: 'user',
        content: queued.content,
      );
      
      _sendMessageInternal(message).catchError((e) {
        _log('Failed to resend message ${queued.id}: $e', level: 'ERROR');
      });
    }
  }

  Future<void> _waitForAuth() async {
    _log('⏳ Waiting for authentication...');
    
    _authComplete = false;
    _authCompleter = Completer<void>();
    
    try {
      await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (!_authComplete) {
            _log('❌ Authentication timeout', level: 'ERROR');
            throw TimeoutException('Authentication timeout');
          }
        },
      );
      _log('✅ Authentication completed');
    } catch (e) {
      _log('❌ Authentication failed: $e', level: 'ERROR');
      rethrow;
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Dispose client
  void dispose() {
    _intentionalDisconnect = true;
    disconnect();
    
    // Close streams safely
    if (!_statusController.isClosed) _statusController.close();
    if (!_messageController.isClosed) _messageController.close();
    if (!_taskStatusController.isClosed) _taskStatusController.close();
    if (!_sendAckController.isClosed) _sendAckController.close();
    if (!_logController.isClosed) _logController.close();
  }

  /// Cancel task
  Future<void> cancelTask(String taskId) async {
    if (!isConnected || _channel == null) {
      throw ConnectionException('Not connected to Gateway');
    }

    final request = {
      'type': 'req',
      'id': 'cancel-$taskId',
      'method': 'cancelTask',
      'params': {'taskId': taskId},
    };

    _channel!.sink.add(jsonEncode(request));
  }

  /// Get task status
  Future<TaskStatus?> getTaskStatus(String taskId) async {
    if (!isConnected || _channel == null) {
      throw ConnectionException('Not connected to Gateway');
    }

    final request = {
      'type': 'req',
      'id': 'status-$taskId',
      'method': 'getTaskStatus',
      'params': {'taskId': taskId},
    };

    _channel!.sink.add(jsonEncode(request));
    return null;
  }

  /// HTTP Polling for messages (方案 2 变体)
  /// 通过 HTTP API 轮询获取消息，而不是依赖 WebSocket 推送
  /// 
  /// 注意：需要先启动 Gateway HTTP API（见 gateway-http-api.js）
  Future<List<Message>> pollMessages({
    String sessionKey = 'agent:main:main',
    int? sinceTimestamp,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // 构造 HTTP API URL（假设在 18790 端口）
      final wsUrl = config.gatewayUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://');
      final httpPort = 18790; // HTTP API 使用不同的端口
      final baseUrl = wsUrl.replaceAll(RegExp(r':\d+'), ':$httpPort');
      
      final uri = Uri.parse('$baseUrl/api/messages').replace(
        queryParameters: {
          'sessionKey': sessionKey,
          if (sinceTimestamp != null) 'since': sinceTimestamp.toString(),
        },
      );
      
      _log('📡 Polling messages from: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${config.token}',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((json) {
          // 确保所有必需字段都存在
          return Message(
            id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            role: json['role']?.toString() ?? 'assistant',
            content: json['content']?.toString() ?? '',
            thinking: json['thinking']?.toString(),
            status: _parseMessageStatus(json['status']),
          );
        }).toList();
        
        _log('✅ Polled ${messages.length} messages');
        return messages;
      } else if (response.statusCode == 401) {
        throw ConnectionException('Unauthorized: Invalid token');
      } else if (response.statusCode == 404) {
        // HTTP API 还没有启动，返回空列表
        _log('⚠️ HTTP API not available (404)', level: 'WARN');
        return [];
      } else {
        throw ConnectionException('HTTP ${response.statusCode}: ${response.body}');
      }
    } on SocketException catch (e) {
      // 连接失败，可能 HTTP API 还没有启动
      _log('⚠️ HTTP API connection failed: $e', level: 'WARN');
      return [];
    } on TimeoutException {
      _log('⚠️ HTTP API timeout', level: 'WARN');
      return [];
    } catch (e) {
      _log('❌ Poll messages error: $e', level: 'ERROR');
      return [];
    }
  }
  
  MessageStatus _parseMessageStatus(dynamic status) {
    if (status == null) return MessageStatus.complete;
    if (status == 'streaming') return MessageStatus.streaming;
    if (status == 'complete') return MessageStatus.complete;
    if (status == 'error') return MessageStatus.error;
    return MessageStatus.complete;
  }
}

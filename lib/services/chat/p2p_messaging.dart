// P2P 消息服务
//
// 实现设备间点对点通信

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';

/// P2P 消息类型
enum P2PMessageType {
  joinRoom,      // 加入房间
  leaveRoom,     // 离开房间
  chatMessage,   // 聊天消息
  userTyping,    // 用户正在输入
  syncRequest,   // 同步请求
  syncResponse,  // 同步响应
}

/// P2P 消息
class P2PMessage {
  final P2PMessageType type;
  final String fromId;
  final String fromName;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  P2PMessage({
    required this.type,
    required this.fromId,
    required this.fromName,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory P2PMessage.fromJson(Map<String, dynamic> json) {
    return P2PMessage(
      type: P2PMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => P2PMessageType.chatMessage,
      ),
      fromId: json['fromId'] ?? '',
      fromName: json['fromName'] ?? 'Unknown',
      payload: json['payload'] ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'fromId': fromId,
    'fromName': fromName,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static P2PMessage decode(String data) {
    return P2PMessage.fromJson(jsonDecode(data));
  }
}

/// P2P 连接
class P2PConnection {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  Socket? socket;
  DateTime connectedAt;

  P2PConnection({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    this.socket,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();
}

/// P2P 消息服务
class P2PMessagingService {
  final Logger _logger = Logger();

  // 本机信息
  String? _localDeviceId;
  String? _localDeviceName;
  int _localPort = 18790;

  // 服务器
  ServerSocket? _server;

  // 连接的设备
  final Map<String, P2PConnection> _connections = {};

  // 流控制器
  final _messageController = StreamController<P2PMessage>.broadcast();
  final _connectionController = StreamController<P2PConnection>.broadcast();
  final _disconnectionController = StreamController<String>.broadcast();

  /// 消息流
  Stream<P2PMessage> get messageStream => _messageController.stream;

  /// 新连接流
  Stream<P2PConnection> get connectionStream => _connectionController.stream;

  /// 断开连接流
  Stream<String> get disconnectionStream => _disconnectionController.stream;

  /// 已连接的设备
  List<P2PConnection> get connections => _connections.values.toList();

  /// 初始化服务
  Future<void> init({
    required String deviceId,
    required String deviceName,
    int port = 18790,
  }) async {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
    _localPort = port;

    await _startServer();
    _logger.i('P2P 消息服务已启动 (端口: $port)');
  }

  /// 启动 TCP 服务器
  Future<void> _startServer() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _localPort,
      );

      _server!.listen(
        _handleIncomingConnection,
        onError: (error) {
          _logger.e('服务器错误: $error');
        },
      );

      _logger.i('TCP 服务器已启动: ${_server!.address.address}:$_localPort');
    } catch (e) {
      _logger.e('启动服务器失败: $e');
    }
  }

  /// 处理入站连接
  void _handleIncomingConnection(Socket socket) {
    _logger.i('新连接: ${socket.remoteAddress.address}:${socket.remotePort}');

    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data);

        // 按换行符分割消息
        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final messageStr = buffer.substring(0, index);
          buffer = buffer.substring(index + 1);

          try {
            final message = P2PMessage.decode(messageStr);
            _handleMessage(message, socket);
          } catch (e) {
            _logger.e('解析消息失败: $e');
          }
        }
      },
      onError: (error) {
        _logger.e('连接错误: $error');
        socket.destroy();
      },
      onDone: () {
        _logger.i('连接关闭: ${socket.remoteAddress.address}');
        _handleDisconnection(socket);
      },
    );
  }

  /// 处理接收到的消息
  void _handleMessage(P2PMessage message, Socket socket) {
    _logger.d('收到消息: ${message.type} from ${message.fromName}');

    // 处理连接注册
    if (message.type == P2PMessageType.joinRoom) {
      final connection = P2PConnection(
        deviceId: message.fromId,
        deviceName: message.fromName,
        ipAddress: socket.remoteAddress.address,
        port: message.payload['port'] ?? 18790,
        socket: socket,
      );

      _connections[message.fromId] = connection;
      _connectionController.add(connection);

      _logger.i('设备已注册: ${message.fromName} (${message.fromId})');
    }

    // 广播消息
    _messageController.add(message);
  }

  /// 处理断开连接
  void _handleDisconnection(Socket socket) {
    final deviceId = _connections.entries
        .where((e) => e.value.socket == socket)
        .map((e) => e.key)
        .firstOrNull;

    if (deviceId != null) {
      _connections.remove(deviceId);
      _disconnectionController.add(deviceId);
      _logger.i('设备已断开: $deviceId');
    }
  }

  /// 连接到远程设备
  Future<bool> connectToDevice({
    required String deviceId,
    required String deviceName,
    required String ipAddress,
    int port = 18790,
  }) async {
    try {
      _logger.i('连接到设备: $deviceName ($ipAddress:$port)');

      final socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));

      final connection = P2PConnection(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        port: port,
        socket: socket,
      );

      _connections[deviceId] = connection;

      // 发送注册消息
      final registerMessage = P2PMessage(
        type: P2PMessageType.joinRoom,
        fromId: _localDeviceId!,
        fromName: _localDeviceName!,
        payload: {
          'port': _localPort,
        },
      );

      socket.writeln(registerMessage.encode());

      // 监听消息
      String buffer = '';
      socket.listen(
        (data) {
          buffer += utf8.decode(data);
          while (buffer.contains('\n')) {
            final index = buffer.indexOf('\n');
            final messageStr = buffer.substring(0, index);
            buffer = buffer.substring(index + 1);

            try {
              final message = P2PMessage.decode(messageStr);
              _messageController.add(message);
            } catch (e) {
              _logger.e('解析消息失败: $e');
            }
          }
        },
        onError: (error) {
          _logger.e('连接错误: $error');
          _connections.remove(deviceId);
          _disconnectionController.add(deviceId);
        },
        onDone: () {
          _logger.i('连接关闭: $deviceName');
          _connections.remove(deviceId);
          _disconnectionController.add(deviceId);
        },
      );

      _logger.i('已连接到设备: $deviceName');
      return true;
    } catch (e) {
      _logger.e('连接失败: $e');
      return false;
    }
  }

  /// 发送消息到指定设备
  bool sendTo(String deviceId, P2PMessage message) {
    final connection = _connections[deviceId];
    if (connection?.socket == null) {
      _logger.w('设备未连接: $deviceId');
      return false;
    }

    try {
      connection!.socket!.writeln(message.encode());
      return true;
    } catch (e) {
      _logger.e('发送消息失败: $e');
      return false;
    }
  }

  /// 广播消息到所有连接的设备
  void broadcast(P2PMessage message) {
    final encoded = message.encode();

    for (final connection in _connections.values) {
      try {
        connection.socket?.writeln(encoded);
      } catch (e) {
        _logger.e('广播失败 (${connection.deviceName}): $e');
      }
    }

    _logger.d('广播消息到 ${_connections.length} 个设备');
  }

  /// 发送聊天消息
  void sendChatMessage({
    required String roomId,
    required String content,
    String? targetDeviceId,
  }) {
    final message = P2PMessage(
      type: P2PMessageType.chatMessage,
      fromId: _localDeviceId!,
      fromName: _localDeviceName!,
      payload: {
        'roomId': roomId,
        'content': content,
      },
    );

    if (targetDeviceId != null) {
      sendTo(targetDeviceId, message);
    } else {
      broadcast(message);
    }
  }

  /// 请求同步
  void requestSync(String roomId, String targetDeviceId) {
    final message = P2PMessage(
      type: P2PMessageType.syncRequest,
      fromId: _localDeviceId!,
      fromName: _localDeviceName!,
      payload: {
        'roomId': roomId,
      },
    );

    sendTo(targetDeviceId, message);
  }

  /// 关闭服务
  Future<void> dispose() async {
    // 关闭所有连接
    for (final connection in _connections.values) {
      connection.socket?.destroy();
    }
    _connections.clear();

    // 关闭服务器
    await _server?.close();

    // 关闭流
    await _messageController.close();
    await _connectionController.close();
    await _disconnectionController.close();

    _logger.i('P2P 消息服务已关闭');
  }
}

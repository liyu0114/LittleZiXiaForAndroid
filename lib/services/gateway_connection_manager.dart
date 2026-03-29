// Gateway 连接管理服务
//
// 管理 Gateway WebSocket 连接

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/gateway_config.dart';

/// Gateway 连接管理器
class GatewayConnectionManager extends ChangeNotifier {
  GatewayConfig? _currentConfig;
  WebSocketChannel? _channel;
  ConnectionInfo _connectionInfo = const ConnectionInfo();
  final StreamController<String> _messageController = StreamController.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Getters
  GatewayConfig? get currentConfig => _currentConfig;
  ConnectionInfo get connectionInfo => _connectionInfo;
  Stream<String> get messageStream => _messageController.stream;
  bool get isConnected => _connectionInfo.isConnected;

  /// 连接到 Gateway
  Future<bool> connect(GatewayConfig config) async {
    if (_connectionInfo.status == ConnectionStatus.connecting) {
      debugPrint('[GatewayConnection] 已在连接中');
      return false;
    }

    _currentConfig = config;
    _updateStatus(ConnectionStatus.connecting);
    _reconnectAttempts = 0;

    try {
      // 测试连接
      final canConnect = await _testConnection(config);
      if (!canConnect) {
        _updateStatus(
          ConnectionStatus.failed,
          errorMessage: '无法连接到 ${config.host}:${config.port}',
        );
        return false;
      }

      // 建立 WebSocket 连接
      _channel = WebSocketChannel.connect(
        Uri.parse(config.wsUrl),
      );

      // 发送握手帧
      await _sendHandshake(config.token);

      // 监听消息
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 启动心跳
      _startPing();

      debugPrint('[GatewayConnection] 已连接到 ${config.name}');
      return true;
    } catch (e) {
      debugPrint('[GatewayConnection] 连接失败: $e');
      _updateStatus(
        ConnectionStatus.failed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 测试 TCP 连接
  Future<bool> _testConnection(GatewayConfig config) async {
    try {
      final socket = await Socket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('[GatewayConnection] TCP 连接测试失败: $e');
      return false;
    }
  }

  /// 发送握手帧
  Future<void> _sendHandshake(String token) async {
    final handshake = jsonEncode({
      'type': 'connect',
      'params': {
        'auth': {'token': token},
      },
    });

    _channel!.sink.add(handshake);
  }

  /// 处理消息
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      debugPrint('[GatewayConnection] 收到消息: $type');

      switch (type) {
        case 'hello-ok':
          _onHandshakeSuccess(data);
          break;
        case 'hello-error':
          _onHandshakeError(data);
          break;
        case 'pong':
          _onPong(data);
          break;
        default:
          // 转发给监听者
          _messageController.add(message);
      }
    } catch (e) {
      debugPrint('[GatewayConnection] 消息解析失败: $e');
      _messageController.add(message);
    }
  }

  /// 握手成功
  void _onHandshakeSuccess(Map<String, dynamic> data) {
    final gatewayInfo = data['gateway'] as Map<String, dynamic>?;
    
    _updateStatus(
      ConnectionStatus.connected,
      connectedAt: DateTime.now(),
      gatewayVersion: gatewayInfo?['version'] as String?,
    );

    _reconnectAttempts = 0;
    debugPrint('[GatewayConnection] 握手成功');
  }

  /// 握手失败
  void _onHandshakeError(Map<String, dynamic> data) {
    final error = data['error'] as String? ?? '认证失败';
    
    _updateStatus(
      ConnectionStatus.authFailed,
      errorMessage: error,
    );

    disconnect();
    debugPrint('[GatewayConnection] 握手失败: $error');
  }

  /// 收到 Pong
  void _onPong(Map<String, dynamic> data) {
    final latency = data['latency'] as int?;
    if (latency != null) {
      _connectionInfo = _connectionInfo.copyWith(
        latency: Duration(milliseconds: latency),
      );
      notifyListeners();
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    debugPrint('[GatewayConnection] 错误: $error');
    _updateStatus(
      ConnectionStatus.failed,
      errorMessage: error.toString(),
    );
    _tryReconnect();
  }

  /// 处理断开
  void _onDone() {
    debugPrint('[GatewayConnection] 连接已断开');
    _updateStatus(ConnectionStatus.disconnected);
    _stopPing();
    _tryReconnect();
  }

  /// 尝试重连
  void _tryReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[GatewayConnection] 已达最大重连次数');
      return;
    }

    if (_currentConfig == null) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    debugPrint('[GatewayConnection] ${delay.inSeconds}秒后尝试第 $_reconnectAttempts 次重连');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentConfig != null) {
        connect(_currentConfig!);
      }
    });
  }

  /// 启动心跳
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _connectionInfo.isConnected) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  /// 停止心跳
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// 更新状态
  void _updateStatus(
    ConnectionStatus status, {
    String? errorMessage,
    DateTime? connectedAt,
    String? gatewayVersion,
  }) {
    _connectionInfo = _connectionInfo.copyWith(
      status: status,
      errorMessage: errorMessage,
      connectedAt: connectedAt,
      gatewayVersion: gatewayVersion,
    );
    notifyListeners();
  }

  /// 断开连接
  void disconnect() {
    _reconnectTimer?.cancel();
    _stopPing();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[GatewayConnection] 已断开连接');
  }

  /// 发送消息
  void send(Map<String, dynamic> message) {
    if (_channel == null || !_connectionInfo.isConnected) {
      debugPrint('[GatewayConnection] 未连接，无法发送消息');
      return;
    }

    _channel!.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}

// WebSocket管理服务
//
// WebSocket连接管理

import 'dart:async';
import 'package:flutter/foundation.dart';

/// WebSocket连接
class WebSocketConnection {
  final String id;
  final String url;
  bool isConnected;
  DateTime? lastPing;
  
  WebSocketConnection({
    required this.id,
    required this.url,
    this.isConnected = false,
    this.lastPing,
  });
}

/// WebSocket管理器
class WebSocketManager extends ChangeNotifier {
  final Map<String, WebSocketConnection> _connections = {};
  Timer? _pingTimer;
  
  /// 连接
  Future<void> connect(String id, String url) async {
    _connections[id] = WebSocketConnection(
      id: id,
      url: url,
      isConnected: true,
      lastPing: DateTime.now(),
    );
    notifyListeners();
  }
  
  /// 断开
  Future<void> disconnect(String id) async {
    _connections[id]?.isConnected = false;
    notifyListeners();
  }
  
  /// 发送消息
  Future<void> send(String id, String message) async {
    final conn = _connections[id];
    if (conn == null || !conn.isConnected) {
      debugPrint('[WebSocketManager] 连接不存在: $id');
      return;
    }
    debugPrint('[WebSocketManager] 发送: $message to $id');
  }
  
  /// 批量发送
  Future<void> broadcast(String message) async {
    for (final conn in _connections.values) {
      if (conn.isConnected) {
        await send(conn.id, message);
      }
    }
  }
  
  /// 停止所有
  void disconnectAll() {
    for (final conn in _connections.values) {
      conn.isConnected = false;
    }
    notifyListeners();
  }
}
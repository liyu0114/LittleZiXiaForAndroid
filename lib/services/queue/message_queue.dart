// 消息队列服务
//
// 异步消息处理

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 队列消息
class QueueMessage {
  final String id;
  final String type;
  final dynamic payload;
  final DateTime createdAt;
  int retryCount;
  
  QueueMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });
}

/// 消息队列
class MessageQueue extends ChangeNotifier {
  final List<QueueMessage> _queue = [];
  static const int MAX_RETRY = 3;
  
  /// 入队
  void enqueue(String type, dynamic payload) {
    _queue.add(QueueMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }
  
  /// 出队
  QueueMessage? dequeue() {
    if (_queue.isEmpty) return null;
    final msg = _queue.removeAt(0);
    notifyListeners();
    return msg;
  }
  
  /// 重试
  void retry(QueueMessage msg) {
    if (msg.retryCount < MAX_RETRY) {
      msg.retryCount++;
      _queue.add(msg);
      notifyListeners();
    }
  }
  
  /// 获取数量
  int get length => _queue.length;
  
  /// 清空
  void clear() {
    _queue.clear();
    notifyListeners();
  }
}
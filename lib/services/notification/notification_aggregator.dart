// 通知聚合服务
//
// 聚合多个渠道的通知

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 通知来源
enum NotificationSource {
  feishu,
  telegram,
  whatsapp,
  discord,
  system,
}

/// 通知
class Notification {
  final String id;
  final NotificationSource source;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  
  Notification({
    required this.id,
    required this.source,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

/// 通知聚合器
class NotificationAggregator extends ChangeNotifier {
  final List<Notification> _notifications = [];
  static const int MAX_NOTIFICATIONS = 100;
  
  List<Notification> get notifications => List.unmodifiable(_notifications);
  List<Notification> get unread => _notifications.where((n) => !n.isRead).toList();
  
  /// 添加通知
  void addNotification(NotificationSource source, String title, String body) {
    final notification = Notification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      source: source,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    if (_notifications.length > MAX_NOTIFICATIONS) {
      _notifications.removeLast();
    }
    notifyListeners();
  }
  
  /// 标记已读
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final n = _notifications[index];
      _notifications[index] = Notification(
        id: n.id,
        source: n.source,
        title: n.title,
        body: n.body,
        timestamp: n.timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }
  
  /// 全部已读
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (!n.isRead) {
        _notifications[i] = Notification(
          id: n.id,
          source: n.source,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          isRead: true,
        );
      }
    }
    notifyListeners();
  }
  
  /// 清空
  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}
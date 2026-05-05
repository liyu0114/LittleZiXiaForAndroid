// 统计服务
//
// 用户行为统计

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 统计事件
class StatEvent {
  final String event;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  
  StatEvent({
    required this.event,
    required this.properties,
    required this.timestamp,
  });
}

/// 统计管理器
class Analytics extends ChangeNotifier {
  final List<StatEvent> _events = [];
  static const int MAX_EVENTS = 500;
  
  /// 跟踪事件
  void track(String event, {Map<String, dynamic>? properties}) {
    _events.add(StatEvent(
      event: event,
      properties: properties ?? {},
      timestamp: DateTime.now(),
    ));
    
    if (_events.length > MAX_EVENTS) {
      _events.removeAt(0);
    }
    notifyListeners();
  }
  
  /// 获取事件数
  int getEventCount(String event) {
    return _events.where((e) => e.event == event).length;
  }
  
  /// 获取今天事件
  List<StatEvent> getTodayEvents() {
    final today = DateTime.now();
    return _events.where((e) => 
      e.timestamp.year == today.year &&
      e.timestamp.month == today.month &&
      e.timestamp.day == today.day
    ).toList();
  }
  
  /// 获取统计数据
  Map<String, int> getStats() {
    final stats = <String, int>{};
    for (final event in _events) {
      stats[event.event] = (stats[event.event] ?? 0) + 1;
    }
    return stats;
  }
  
  /// 清空
  void clear() {
    _events.clear();
    notifyListeners();
  }
}
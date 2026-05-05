// 日志分析服务
//
// 分析和可视化日志数据

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final String level; // info/warning/error
  final String source;
  final String message;
  
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'source': source,
    'message': message,
  };
}

/// 日志分析器
class LogAnalyzer extends ChangeNotifier {
  final List<LogEntry> _logs = [];
  static const int MAX_LOGS = 1000;
  
  List<LogEntry> get logs => List.unmodifiable(_logs);
  
  /// 添加日志
  void addLog(String level, String source, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );
    
    _logs.add(entry);
    if (_logs.length > MAX_LOGS) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }
  
  /// 获取错误
  List<LogEntry> getErrors() {
    return _logs.where((l) => l.level == 'error').toList();
  }
  
  /// 获取警告
  List<LogEntry> getWarnings() {
    return _logs.where((l) => l.level == 'warning').toList();
  }
  
  /// 搜索
  List<LogEntry> search(String query) {
    return _logs.where((l) => 
      l.message.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  /// 统计
  Map<String, int> getStatistics() {
    return {
      'total': _logs.length,
      'error': _logs.where((l) => l.level == 'error').length,
      'warning': _logs.where((l) => l.level == 'warning').length,
      'info': _logs.where((l) => l.level == 'info').length,
    };
  }
  
  /// 清空
  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
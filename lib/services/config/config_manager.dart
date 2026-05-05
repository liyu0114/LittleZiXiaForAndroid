// 配置管理服务
//
// 运行时配置热更新

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 配置条目
class ConfigEntry {
  final String key;
  dynamic value;
  final String? description;
  final DateTime updatedAt;
  
  ConfigEntry({
    required this.key,
    required this.value,
    this.description,
    required this.updatedAt,
  });
}

/// 配置管理器
class ConfigManager extends ChangeNotifier {
  final Map<String, ConfigEntry> _configs = {};
  
  /// 获取配置
  T? get<T>(String key) {
    final entry = _configs[key];
    if (entry == null) return null;
    return entry.value as T;
  }
  
  /// 设置配置
  void set<T>(String key, T value, {String? description}) {
    _configs[key] = ConfigEntry(
      key: key,
      value: value,
      description: description,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
  
  /// 删除配置
  void remove(String key) {
    _configs.remove(key);
    notifyListeners();
  }
  
  /// 获取所有
  Map<String, dynamic> getAll() {
    return _configs.map((key, entry) => MapEntry(key, entry.value));
  }
  
  /// 初始化默认配置
  void initDefaults() {
    set('debug', false, description: '调试模式');
    set('maxRetries', 3, description: '最大重试次数');
    set('timeout', 30000, description: '超时(ms)');
    notifyListeners();
  }
}
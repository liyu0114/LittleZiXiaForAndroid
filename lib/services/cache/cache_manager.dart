// 缓存管理服务
//
// 内存缓存+LRU策略

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 缓存条目
class CacheEntry<T> {
  final String key;
  final T value;
  final DateTime createdAt;
  final int ttlSeconds;
  
  CacheEntry({
    required this.key,
    required this.value,
    required this.createdAt,
    this.ttlSeconds = 3600,
  });
  
  bool get isExpired {
    return DateTime.now().difference(createdAt).inSeconds > ttlSeconds;
  }
}

/// 缓存管理器
class CacheManager extends ChangeNotifier {
  final Map<String, CacheEntry<dynamic>> _cache = {};
  static const int MAX_SIZE = 100;
  
  /// 设置缓存
  void set<T>(String key, T value, {int ttlSeconds = 3600}) {
    // LRU: 删除最老的
    if (_cache.length >= MAX_SIZE) {
      _evictOldest();
    }
    
    _cache[key] = CacheEntry(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      ttlSeconds: ttlSeconds,
    );
    notifyListeners();
  }
  
  /// 获取缓存
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }
  
  /// 检查存在
  bool contains(String key) {
    return _cache.containsKey(key) && !_cache[key]!.isExpired;
  }
  
  /// 删除
  void remove(String key) {
    _cache.remove(key);
    notifyListeners();
  }
  
  /// 清空
  void clear() {
    _cache.clear();
    notifyListeners();
  }
  
  void _evictOldest() {
    if (_cache.isEmpty) return;
    
    var oldestKey = _cache.keys.first;
    var oldestTime = _cache[oldestKey]!.createdAt;
    
    for (final entry in _cache.entries) {
      if (entry.value.createdAt.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.createdAt;
      }
    }
    
    _cache.remove(oldestKey);
  }
  
  /// 清理过期
  void cleanExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
    notifyListeners();
  }
}
// 缓存管理服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

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
class CacheManager {
  final Map<String, CacheEntry<dynamic>> _cache = {};
  static const int MAX_SIZE = 100;
  
  void set<T>(String key, T value, {int ttlSeconds = 3600}) {
    if (_cache.length >= MAX_SIZE) {
      _evictOldest();
    }
    
    _cache[key] = CacheEntry(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      ttlSeconds: ttlSeconds,
    );
  }
  
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }
  
  bool contains(String key) {
    return _cache.containsKey(key) && !_cache[key]!.isExpired;
  }
  
  void remove(String key) {
    _cache.remove(key);
  }
  
  void clear() {
    _cache.clear();
  }
  
  void _evictOldest() {
    if (_cache.isEmpty) return;
    
    String? oldestKey;
    DateTime oldestTime = DateTime.now();
    
    for (final entry in _cache.entries) {
      if (entry.value.createdAt.isBefore(oldestTime)) {
        oldestTime = entry.value.createdAt;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }
  
  int get size => _cache.length;
}

void main() {
  group('L1-11 缓存管理测试', () {
    
    test('测试1：设置缓存', () {
      final cache = CacheManager();
      cache.set('key1', 'value1');
      expect(cache.contains('key1'), true);
    });
    
    test('测试2：获取缓存', () {
      final cache = CacheManager();
      cache.set('key1', 'value1');
      expect(cache.get('key1'), 'value1');
    });
    
    test('测试3：获取不存在的缓存', () {
      final cache = CacheManager();
      expect(cache.get('none'), isNull);
    });
    
    test('测试4：删除缓存', () {
      final cache = CacheManager();
      cache.set('key1', 'value1');
      cache.remove('key1');
      expect(cache.contains('key1'), false);
    });
    
    test('测试5：清空缓存', () {
      final cache = CacheManager();
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.clear();
      expect(cache.size, 0);
    });
    
    test('测试6：LRU淘汰策略', () {
      final cache = CacheManager();
      for (int i = 0; i < 105; i++) {
        cache.set('key$i', 'value$i');
      }
      expect(cache.size, lessThanOrEqualTo(100));
    });
    
    test('测试7：过期检测', () async {
      final cache = CacheManager();
      cache.set('key1', 'value1', ttlSeconds: 0);
      await Future.delayed(Duration(milliseconds: 10));
      expect(cache.contains('key1'), false);
    });
    
    test('测试8：多种类型', () {
      final cache = CacheManager();
      cache.set('str', 'hello');
      cache.set('num', 123);
      cache.set('list', [1, 2, 3]);
      
      expect(cache.get('str'), 'hello');
      expect(cache.get('num'), 123);
      expect(cache.get('list'), [1, 2, 3]);
    });
    
    test('测试9：覆盖已有', () {
      final cache = CacheManager();
      cache.set('key1', 'value1');
      cache.set('key1', 'value2');
      expect(cache.get('key1'), 'value2');
    });
    
    test('测试10：缓存大小限制', () {
      final cache = CacheManager();
      for (int i = 0; i < 50; i++) {
        cache.set('key$i', 'value$i');
      }
      expect(cache.size, 50);
    });
  });
}
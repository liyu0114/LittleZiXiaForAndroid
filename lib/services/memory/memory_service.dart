// Memory 系统服务
//
// 向 OpenClaw 的 memory 琜索功能看齐

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Memory 条目
class MemoryEntry {
  final String id;
  final String content;
  final DateTime timestamp;
  final List<String> tags;
  final double? embedding;

  MemoryEntry({
    required this.id,
    required this.content,
    required this.timestamp,
    this.tags = const [],
    this.embedding,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
      if (embedding != null) 'embedding': embedding,
    };
  }

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      tags: List<String>.from(json['tags'] ?? []),
      embedding: json['embedding']?.toDouble(),
    );
  }
}

/// Memory 搜索结果
class MemorySearchResult {
  final MemoryEntry entry;
  final double score;
  final String? highlight;

  MemorySearchResult({
    required this.entry,
    required this.score,
    this.highlight,
  });
}

/// Memory 服务
class MemoryService {
  static const String _storageKey = 'memory_entries';
  
  final List<MemoryEntry> _entries = [];
  bool _isLoaded = false;

  /// 获取所有条目
  List<MemoryEntry> get entries => List.unmodifiable(_entries);

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 加载 Memory
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _entries.clear();
        for (final item in list) {
          _entries.add(MemoryEntry.fromJson(item));
        }
      }
      
      _isLoaded = true;
      print('[MemoryService] 加载了 ${_entries.length} 条记忆');
    } catch (e) {
      print('[MemoryService] 加载失败: $e');
    }
  }

  /// 保存 Memory
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, json);
      print('[MemoryService] 保存了 ${_entries.length} 条记忆');
    } catch (e) {
      print('[MemoryService] 保存失败: $e');
    }
  }

  /// 添加条目
  Future<void> add(String content, {List<String>? tags}) async {
    final entry = MemoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      tags: tags ?? [],
    );
    
    _entries.add(entry);
    await save();
  }

  /// 删除条目
  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await save();
  }

  /// 清空所有条目
  Future<void> clear() async {
    _entries.clear();
    await save();
  }

  /// 搜索条目（关键词匹配）
  List<MemorySearchResult> search(String query, {int maxResults = 5}) {
    final results = <MemorySearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final entry in _entries) {
      final score = _calculateScore(entry, lowerQuery);
      if (score > 0) {
        results.add(MemorySearchResult(
          entry: entry,
          score: score,
          highlight: _extractHighlight(entry.content, lowerQuery),
        ));
      }
    }

    // 按分数排序
    results.sort((a, b) => b.score.compareTo(a.score));
    
    return results.take(maxResults).toList();
  }

  /// 计算匹配分数
  double _calculateScore(MemoryEntry entry, String query) {
    final content = entry.content.toLowerCase();
    
    // 完全匹配
    if (content.contains(query)) {
      return 1.0;
    }
    
    // 标签匹配
    for (final tag in entry.tags) {
      if (tag.toLowerCase().contains(query)) {
        return 0.8;
      }
    }
    
    // 部分匹配
    final words = query.split(' ');
    int matchCount = 0;
    for (final word in words) {
      if (content.contains(word)) {
        matchCount++;
      }
    }
    
    return matchCount / words.length * 0.5;
  }

  /// 提取高亮文本
  String? _extractHighlight(String content, String query) {
    final lowerContent = content.toLowerCase();
    final index = lowerContent.indexOf(query);
    
    if (index == -1) return null;
    
    final start = index > 50 ? index - 50 : 0;
    final end = index + query.length + 50;
    
    final highlight = content.substring(start, end);
    return highlight;
  }

  /// 获取指定条目
  MemoryEntry? get(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取最近的条目
  List<MemoryEntry> getRecent({int count = 10}) {
    final sorted = List<MemoryEntry>.from(_entries);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(count).toList();
  }
}

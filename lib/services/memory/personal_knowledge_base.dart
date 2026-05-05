/// 个人知识库
/// 
/// 结构化的长期记忆，按需检索注入

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 知识分类
enum KnowledgeCategory {
  project,     // 项目知识
  technical,   // 技术知识
  experience,  // 经验知识
  skill,       // 技能知识
  contact,     // 人脉知识
  life,        // 生活知识
}

/// 知识分类扩展
extension KnowledgeCategoryExtension on KnowledgeCategory {
  String get displayName {
    switch (this) {
      case KnowledgeCategory.project:
        return '项目知识';
      case KnowledgeCategory.technical:
        return '技术知识';
      case KnowledgeCategory.experience:
        return '经验知识';
      case KnowledgeCategory.skill:
        return '技能知识';
      case KnowledgeCategory.contact:
        return '人脉知识';
      case KnowledgeCategory.life:
        return '生活知识';
    }
  }
  
  String get icon {
    switch (this) {
      case KnowledgeCategory.project:
        return '📁';
      case KnowledgeCategory.technical:
        return '💻';
      case KnowledgeCategory.experience:
        return '💡';
      case KnowledgeCategory.skill:
        return '🎯';
      case KnowledgeCategory.contact:
        return '👥';
      case KnowledgeCategory.life:
        return '🏠';
    }
  }
}

/// 知识条目
class KnowledgeEntry {
  final String id;
  final String title;
  final String summary;        // 摘要（给 LLM 看的）
  final String content;        // 完整内容
  final KnowledgeCategory category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  int accessCount;             // 访问次数
  final double importance;     // 重要性（0-1）
  final DateTime? expiresAt;   // 过期时间（可选）
  final List<String> relatedIds; // 相关知识点
  
  KnowledgeEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.accessCount = 0,
    this.importance = 0.5,
    this.expiresAt,
    this.relatedIds = const [],
  });
  
  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return KnowledgeEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      content: json['content'] as String,
      category: KnowledgeCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => KnowledgeCategory.life,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      accessCount: json['accessCount'] as int? ?? 0,
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String) 
          : null,
      relatedIds: List<String>.from(json['relatedIds'] ?? []),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'category': category.name,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'accessCount': accessCount,
      'importance': importance,
      'expiresAt': expiresAt?.toIso8601String(),
      'relatedIds': relatedIds,
    };
  }
  
  KnowledgeEntry copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    KnowledgeCategory? category,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? accessCount,
    double? importance,
    DateTime? expiresAt,
    List<String>? relatedIds,
  }) {
    return KnowledgeEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accessCount: accessCount ?? this.accessCount,
      importance: importance ?? this.importance,
      expiresAt: expiresAt ?? this.expiresAt,
      relatedIds: relatedIds ?? this.relatedIds,
    );
  }
  
  /// 是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

/// 个人知识库
class PersonalKnowledgeBase extends ChangeNotifier {
  static const String _storageKey = 'personal_knowledge';
  
  final Map<String, KnowledgeEntry> _entries = {};
  final Map<String, List<String>> _categoryIndex = {};
  final Map<String, List<String>> _tagIndex = {};
  
  bool _isLoaded = false;
  
  // Getters
  List<KnowledgeEntry> get allEntries => _entries.values.toList();
  bool get isLoaded => _isLoaded;
  int get count => _entries.length;
  
  /// 初始化 - 加载知识库
  Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        _entries.clear();
        _categoryIndex.clear();
        _tagIndex.clear();
        
        for (final item in list) {
          final entry = KnowledgeEntry.fromJson(item as Map<String, dynamic>);
          _addEntryToIndex(entry);
        }
      }
      
      _isLoaded = true;
      debugPrint('[KnowledgeBase] 加载了 ${_entries.length} 条知识');
      notifyListeners();
    } catch (e) {
      debugPrint('[KnowledgeBase] 加载失败: $e');
    }
  }
  
  /// 添加条目到索引
  void _addEntryToIndex(KnowledgeEntry entry) {
    _entries[entry.id] = entry;
    
    // 分类索引
    _categoryIndex.putIfAbsent(entry.category.name, () => []);
    if (!_categoryIndex[entry.category.name]!.contains(entry.id)) {
      _categoryIndex[entry.category.name]!.add(entry.id);
    }
    
    // 标签索引
    for (final tag in entry.tags) {
      _tagIndex.putIfAbsent(tag, () => []);
      if (!_tagIndex[tag]!.contains(entry.id)) {
        _tagIndex[tag]!.add(entry.id);
      }
    }
  }
  
  /// 保存知识库
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _entries.values.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      debugPrint('[KnowledgeBase] 保存了 ${_entries.length} 条知识');
    } catch (e) {
      debugPrint('[KnowledgeBase] 保存失败: $e');
    }
  }
  
  /// 添加知识
  Future<void> addEntry(KnowledgeEntry entry) async {
    _addEntryToIndex(entry);
    await save();
    notifyListeners();
    debugPrint('[KnowledgeBase] 添加知识: ${entry.title}');
  }
  
  /// 更新知识
  Future<void> updateEntry(KnowledgeEntry entry) async {
    // 先删除旧索引
    final oldEntry = _entries[entry.id];
    if (oldEntry != null) {
      _categoryIndex[oldEntry.category.name]?.remove(entry.id);
      for (final tag in oldEntry.tags) {
        _tagIndex[tag]?.remove(entry.id);
      }
    }
    
    // 添加新条目
    _addEntryToIndex(entry.copyWith(updatedAt: DateTime.now()));
    await save();
    notifyListeners();
    debugPrint('[KnowledgeBase] 更新知识: ${entry.id}');
  }
  
  /// 删除知识
  Future<void> deleteEntry(String id) async {
    final entry = _entries[id];
    if (entry != null) {
      // 删除索引
      _categoryIndex[entry.category.name]?.remove(id);
      for (final tag in entry.tags) {
        _tagIndex[tag]?.remove(id);
      }
      
      _entries.remove(id);
      await save();
      notifyListeners();
      debugPrint('[KnowledgeBase] 删除知识: $id');
    }
  }
  
  /// 按分类获取
  List<KnowledgeEntry> getByCategory(KnowledgeCategory category) {
    final ids = _categoryIndex[category.name] ?? [];
    return ids.map((id) => _entries[id]).whereType<KnowledgeEntry>().toList();
  }
  
  /// 按标签获取
  List<KnowledgeEntry> getByTag(String tag) {
    final ids = _tagIndex[tag] ?? [];
    return ids.map((id) => _entries[id]).whereType<KnowledgeEntry>().toList();
  }
  
  /// 搜索知识
  List<KnowledgeEntry> search(String query, {int maxResults = 10}) {
    final scores = <String, double>{};
    final lowerQuery = query.toLowerCase();
    
    for (final entry in _entries.values) {
      double score = 0;
      
      // 标题匹配（权重 0.4）
      if (entry.title.toLowerCase().contains(lowerQuery)) {
        score += 0.4;
      }
      
      // 摘要匹配（权重 0.3）
      if (entry.summary.toLowerCase().contains(lowerQuery)) {
        score += 0.3;
      }
      
      // 标签匹配（权重 0.2）
      for (final tag in entry.tags) {
        if (tag.toLowerCase().contains(lowerQuery)) {
          score += 0.2;
          break;
        }
      }
      
      // 重要性加权（权重 0.1）
      score += entry.importance * 0.1;
      
      if (score > 0) {
        scores[entry.id] = score;
      }
    }
    
    // 排序并返回 top N
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final results = sorted
      .take(maxResults)
      .map((e) => _entries[e.key]!)
      .toList();
    
    // 增加访问计数
    for (final entry in results) {
      entry.accessCount++;
    }
    save();
    
    return results;
  }
  
  /// 生成知识摘要（给 LLM 用）
  String generateSummary({KnowledgeCategory? category, List<String>? tags}) {
    List<KnowledgeEntry> entries;
    
    if (category != null) {
      entries = getByCategory(category);
    } else if (tags != null && tags.isNotEmpty) {
      entries = tags.expand((t) => getByTag(t)).toSet().toList();
    } else {
      entries = allEntries.take(20).toList();  // 最多20条
    }
    
    if (entries.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('## 个人知识库');
    buffer.writeln();
    
    for (final entry in entries) {
      buffer.writeln('- **${entry.title}**: ${entry.summary}');
    }
    
    return buffer.toString();
  }
  
  /// 获取相关知识
  List<KnowledgeEntry> getRelated(String entryId) {
    final entry = _entries[entryId];
    if (entry == null) return [];
    
    final related = <KnowledgeEntry>[];
    
    // 通过 relatedIds 获取
    for (final id in entry.relatedIds) {
      final relatedEntry = _entries[id];
      if (relatedEntry != null) {
        related.add(relatedEntry);
      }
    }
    
    // 通过标签获取相似知识
    for (final tag in entry.tags) {
      final tagEntries = getByTag(tag);
      for (final tagEntry in tagEntries) {
        if (tagEntry.id != entryId && !related.any((e) => e.id == tagEntry.id)) {
          related.add(tagEntry);
        }
      }
    }
    
    return related.take(5).toList();
  }
  
  /// 检测过期知识
  List<KnowledgeEntry> findExpired() {
    return _entries.values.where((e) => e.isExpired).toList();
  }
  
  /// 清理过期知识
  Future<void> cleanExpired() async {
    final expired = findExpired();
    for (final entry in expired) {
      await deleteEntry(entry.id);
    }
    debugPrint('[KnowledgeBase] 清理了 ${expired.length} 条过期知识');
  }
  
  /// 获取统计信息
  Map<String, dynamic> get statistics {
    final stats = <String, int>{};
    for (final category in KnowledgeCategory.values) {
      stats[category.name] = getByCategory(category).length;
    }
    
    final totalAccess = _entries.values.fold<int>(0, (sum, e) => sum + e.accessCount);
    
    return {
      'total': count,
      'byCategory': stats,
      'totalAccess': totalAccess,
      'tagCount': _tagIndex.length,
    };
  }
  
  /// 清空所有知识
  Future<void> clear() async {
    _entries.clear();
    _categoryIndex.clear();
    _tagIndex.clear();
    await save();
    notifyListeners();
    debugPrint('[KnowledgeBase] 清空所有知识');
  }
}

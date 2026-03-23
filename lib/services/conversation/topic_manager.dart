// 对话话题管理服务
//
// 学习 DeepSeek 的话题管理模式，支持多话题切换和历史记忆

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../llm/llm_base.dart';

/// 话题状态
enum TopicStatus {
  active,    // 活跃中
  archived,  // 已归档
  deleted,   // 已删除
}

/// 对话话题
class ConversationTopic {
  final String id;
  String title;               // 话题标题
  String summary;             // 话题摘要（LLM 生成）
  List<String> keywords;      // 关键词
  final DateTime createdAt;
  DateTime lastActiveAt;
  int messageCount;
  TopicStatus status;
  
  // 对话历史（完整消息）
  List<ChatMessage> messages;
  
  // 记忆摘要（压缩的长对话）
  String? memorySummary;

  ConversationTopic({
    required this.id,
    required this.title,
    this.summary = '',
    this.keywords = const [],
    DateTime? createdAt,
    DateTime? lastActiveAt,
    this.messageCount = 0,
    this.status = TopicStatus.active,
    List<ChatMessage>? messages,
    this.memorySummary,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now(),
        messages = messages ?? [];

  factory ConversationTopic.fromJson(Map<String, dynamic> json) {
    return ConversationTopic(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      messageCount: json['messageCount'] as int? ?? 0,
      status: TopicStatus.values[json['status'] as int? ?? 0],
      memorySummary: json['memorySummary'] as String?,
      // messages 需要单独加载（可能很大）
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'keywords': keywords,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'messageCount': messageCount,
      'status': status.index,
      'memorySummary': memorySummary,
    };
  }

  /// 更新活跃时间
  void touch() {
    lastActiveAt = DateTime.now();
  }

  /// 添加消息
  void addMessage(ChatMessage message) {
    messages.add(message);
    messageCount++;
    touch();
  }

  /// 获取显示标题
  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (summary.isNotEmpty) return summary;
    return '新对话';
  }
}

/// 话题管理器
class TopicManager extends ChangeNotifier {
  List<ConversationTopic> _topics = [];
  String? _currentTopicId;
  final int _maxTopics = 100;        // 最大话题数
  final int _maxMessagesPerTopic = 100; // 每个话题最大消息数
  
  List<ConversationTopic> get topics => _topics;
  ConversationTopic? get currentTopic => _currentTopicId != null
      ? _topics.where((t) => t.id == _currentTopicId).firstOrNull
      : null;
  
  /// 获取活跃话题
  List<ConversationTopic> get activeTopics =>
      _topics.where((t) => t.status == TopicStatus.active).toList();
  
  /// 获取归档话题
  List<ConversationTopic> get archivedTopics =>
      _topics.where((t) => t.status == TopicStatus.archived).toList();

  /// 创建新话题
  ConversationTopic createTopic({String? title}) {
    final topic = ConversationTopic(
      id: 'topic_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? '新对话',
    );
    
    _topics.insert(0, topic);
    _currentTopicId = topic.id;
    
    // 限制话题数量
    if (_topics.length > _maxTopics) {
      _topics.removeRange(_maxTopics, _topics.length);
    }
    
    notifyListeners();
    return topic;
  }

  /// 切换话题
  void switchTopic(String topicId) {
    if (_topics.any((t) => t.id == topicId)) {
      _currentTopicId = topicId;
      _topics.firstWhere((t) => t.id == topicId).touch();
      notifyListeners();
    }
  }

  /// 更新话题标题
  void updateTopicTitle(String topicId, String title) {
    final topic = _topics.where((t) => t.id == topicId).firstOrNull;
    if (topic != null) {
      topic.title = title;
      notifyListeners();
    }
  }

  /// 归档话题
  void archiveTopic(String topicId) {
    final topic = _topics.where((t) => t.id == topicId).firstOrNull;
    if (topic != null) {
      topic.status = TopicStatus.archived;
      if (_currentTopicId == topicId) {
        _currentTopicId = activeTopics.firstOrNull?.id;
      }
      notifyListeners();
    }
  }

  /// 删除话题
  void deleteTopic(String topicId) {
    _topics.removeWhere((t) => t.id == topicId);
    if (_currentTopicId == topicId) {
      _currentTopicId = activeTopics.firstOrNull?.id;
    }
    notifyListeners();
  }

  /// 搜索话题
  List<ConversationTopic> searchTopics(String query) {
    final lowerQuery = query.toLowerCase();
    return _topics.where((t) {
      return t.title.toLowerCase().contains(lowerQuery) ||
          t.summary.toLowerCase().contains(lowerQuery) ||
          t.keywords.any((k) => k.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// 按日期分组
  Map<String, List<ConversationTopic>> groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));
    final thisMonth = today.subtract(const Duration(days: 30));

    final groups = <String, List<ConversationTopic>>{
      '今天': [],
      '昨天': [],
      '本周': [],
      '本月': [],
      '更早': [],
    };

    for (final topic in activeTopics) {
      final topicDate = DateTime(
        topic.lastActiveAt.year,
        topic.lastActiveAt.month,
        topic.lastActiveAt.day,
      );

      if (topicDate == today) {
        groups['今天']!.add(topic);
      } else if (topicDate == yesterday) {
        groups['昨天']!.add(topic);
      } else if (topicDate.isAfter(thisWeek)) {
        groups['本周']!.add(topic);
      } else if (topicDate.isAfter(thisMonth)) {
        groups['本月']!.add(topic);
      } else {
        groups['更早']!.add(topic);
      }
    }

    return groups;
  }

  /// 保存到本地
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topicsJson = _topics.map((t) => t.toJson()).toList();
      await prefs.setString('conversation_topics', jsonEncode(topicsJson));
      await prefs.setString('current_topic_id', _currentTopicId ?? '');
    } catch (e) {
      debugPrint('[TopicManager] 保存失败: $e');
    }
  }

  /// 从本地加载
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topicsJson = prefs.getString('conversation_topics');
      final currentId = prefs.getString('current_topic_id');

      if (topicsJson != null) {
        final List<dynamic> list = jsonDecode(topicsJson);
        _topics = list.map((json) => ConversationTopic.fromJson(json)).toList();
      }

      if (currentId != null && currentId.isNotEmpty) {
        _currentTopicId = currentId;
      } else if (_topics.isNotEmpty) {
        _currentTopicId = _topics.first.id;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[TopicManager] 加载失败: $e');
    }
  }

  /// 压缩话题记忆（当消息数超过限制时）
  Future<void> compressTopicMemory(
    ConversationTopic topic,
    Future<String> Function(List<ChatMessage>) summarizeFunction,
  ) async {
    if (topic.messages.length <= _maxMessagesPerTopic) return;

    // 保留最近的消息
    final messagesToCompress = topic.messages
        .sublist(0, topic.messages.length - _maxMessagesPerTopic ~/ 2);
    topic.messages = topic.messages
        .sublist(topic.messages.length - _maxMessagesPerTopic ~/ 2);

    // 生成摘要
    try {
      final summary = await summarizeFunction(messagesToCompress);
      topic.memorySummary = (topic.memorySummary ?? '') + '\n\n' + summary;
    } catch (e) {
      debugPrint('[TopicManager] 压缩记忆失败: $e');
    }
  }
}

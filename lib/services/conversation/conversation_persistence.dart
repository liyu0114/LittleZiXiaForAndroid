// 对话持久化服务
//
// 保存和加载对话历史到本地数据库

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 对话消息持久化模型
class PersistedMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? topicId;
  final Map<String, dynamic>? metadata;

  PersistedMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.topicId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (topicId != null) 'topicId': topicId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory PersistedMessage.fromJson(Map<String, dynamic> json) {
    return PersistedMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      topicId: json['topicId'],
      metadata: json['metadata'],
    );
  }
}

/// 对话持久化服务
class ConversationPersistenceService {
  static const String _messagesKey = 'persisted_messages';
  static const String _topicsKey = 'persisted_topics';
  
  final SharedPreferences _prefs;
  List<PersistedMessage> _messages = [];
  Map<String, String> _topicNames = {};
  bool _isLoaded = false;

  ConversationPersistenceService(this._prefs);

  /// 加载所有消息
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      // 加载消息
      final messagesJson = _prefs.getString(_messagesKey);
      if (messagesJson != null) {
        final List<dynamic> list = jsonDecode(messagesJson);
        _messages = list.map((m) => PersistedMessage.fromJson(m)).toList();
      }

      // 加载话题名称
      final topicsJson = _prefs.getString(_topicsKey);
      if (topicsJson != null) {
        final Map<String, dynamic> map = jsonDecode(topicsJson);
        _topicNames = map.map((k, v) => MapEntry(k, v.toString()));
      }

      _isLoaded = true;
      print('[ConversationPersistence] 加载了 ${_messages.length} 条消息');
    } catch (e) {
      print('[ConversationPersistence] 加载失败: $e');
    }
  }

  /// 保存所有消息
  Future<void> save() async {
    try {
      final messagesJson = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await _prefs.setString(_messagesKey, messagesJson);

      final topicsJson = jsonEncode(_topicNames);
      await _prefs.setString(_topicsKey, topicsJson);

      print('[ConversationPersistence] 保存了 ${_messages.length} 条消息');
    } catch (e) {
      print('[ConversationPersistence] 保存失败: $e');
    }
  }

  /// 添加消息
  Future<void> addMessage(PersistedMessage message) async {
    _messages.add(message);
    await save();
  }

  /// 获取话题的所有消息
  List<PersistedMessage> getMessagesByTopic(String? topicId) {
    if (topicId == null) {
      return _messages;
    }
    return _messages.where((m) => m.topicId == topicId).toList();
  }

  /// 获取最近的消息
  List<PersistedMessage> getRecentMessages({int count = 50}) {
    return _messages.skip(_messages.length > count ? _messages.length - count : 0).toList();
  }

  /// 清空所有消息
  Future<void> clear() async {
    _messages.clear();
    _topicNames.clear();
    await save();
  }

  /// 设置话题名称
  Future<void> setTopicName(String topicId, String name) async {
    _topicNames[topicId] = name;
    await save();
  }

  /// 获取话题名称
  String? getTopicName(String topicId) {
    return _topicNames[topicId];
  }

  /// 导出对话
  Future<String?> exportConversation({String? topicId}) async {
    try {
      final messages = getMessagesByTopic(topicId);
      if (messages.isEmpty) return null;

      final buffer = StringBuffer();
      buffer.writeln('# 对话导出');
      buffer.writeln('# 导出时间: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');

      for (final message in messages) {
        final roleLabel = message.role == 'user' ? '用户' : '助手';
        final time = message.timestamp.toString();
        buffer.writeln('## [$time] $roleLabel');
        buffer.writeln(message.content);
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      print('[ConversationPersistence] 导出失败: $e');
      return null;
    }
  }

  /// 导出为 JSON
  Future<String?> exportAsJson({String? topicId}) async {
    try {
      final messages = getMessagesByTopic(topicId);
      if (messages.isEmpty) return null;

      final data = {
        'exportedAt': DateTime.now().toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

      return jsonEncode(data);
    } catch (e) {
      print('[ConversationPersistence] JSON 导出失败: $e');
      return null;
    }
  }
}

/// MapEntry 辅助类
class MapEntry<K, V> {
  final K key;
  final V value;
  MapEntry(this.key, this.value);
}

/// Map 扩展方法
extension MapExtension<K, V> on Map<K, V> {
  List<MapEntry<K, V>> get entries => 
      entries.map((e) => MapEntry(e.key, e.value)).toList();
}

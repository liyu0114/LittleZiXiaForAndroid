// 群聊机器人服务
//
// 为联网群聊提供 AI 机器人参与对话

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// 机器人配置
class BotConfig {
  final String id;
  final String name;
  final String personality;  // 个性描述
  final bool enabled;
  
  BotConfig({
    required this.id,
    required this.name,
    this.personality = '友好、幽默、乐于助人',
    this.enabled = true,
  });
  
  /// 默认机器人
  static BotConfig defaultBot() => BotConfig(
    id: 'bot_xiaozixia',
    name: '小紫霞',
    personality: '友好、幽默、乐于助人的 AI 助手，会用简洁的方式回复，偶尔会开玩笑',
  );
}

/// 简化的 LLM 消息
class SimpleChatMessage {
  final String role;  // system, user, assistant
  final String content;
  
  SimpleChatMessage(this.role, this.content);
  
  static SimpleChatMessage system(String content) => SimpleChatMessage('system', content);
  static SimpleChatMessage user(String content) => SimpleChatMessage('user', content);
}

/// 群聊机器人服务
class ChatBotService extends ChangeNotifier {
  final String? _llmEndpoint;  // LLM API 端点
  final String? _llmApiKey;    // LLM API 密钥
  final BotConfig _config;
  
  // 对话历史（用于上下文）
  final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 20;  // 保留最近 20 条消息
  
  // 回复概率（0-1）
  final double _replyProbability;
  
  // 延迟回复范围（毫秒）
  final int _minReplyDelay;
  final int _maxReplyDelay;
  
  // 随机数生成器
  final _random = Random();
  
  // 关键词触发（这些词会提高回复概率）
  static const List<String> _triggerKeywords = [
    '小紫霞', '机器人', 'bot', 'ai', 'AI', '紫霞',
    '吗', '呢', '？', '?', '怎么', '什么', '为什么', '如何',
    '大家', '你们', '有人', '知道',
  ];
  
  ChatBotService({
    String? llmEndpoint,
    String? llmApiKey,
    BotConfig? config,
    double replyProbability = 0.3,
    int minReplyDelay = 1500,
    int maxReplyDelay = 4000,
  }) : _llmEndpoint = llmEndpoint,
       _llmApiKey = llmApiKey,
       _config = config ?? BotConfig.defaultBot(),
       _replyProbability = replyProbability,
       _minReplyDelay = minReplyDelay,
       _maxReplyDelay = maxReplyDelay;

  String get botId => _config.id;
  String get botName => _config.name;
  
  /// 添加消息到历史
  void addToHistory(String userId, String userName, String content) {
    _conversationHistory.add({
      'userId': userId,
      'userName': userName,
      'content': content,
      'time': DateTime.now().toIso8601String(),
    });
    
    // 限制历史长度
    if (_conversationHistory.length > _maxHistoryLength) {
      _conversationHistory.removeAt(0);
    }
  }
  
  /// 清空历史
  void clearHistory() {
    _conversationHistory.clear();
  }
  
  /// 决定是否回复
  bool shouldReply(String message, String senderId) {
    if (senderId == botId) return false;  // 不回复自己
    
    // 被直接提及
    if (message.contains(_config.name) || 
        message.contains('小紫霞') ||
        message.contains('@${_config.name}')) {
      return true;
    }
    
    // 包含触发关键词
    for (final keyword in _triggerKeywords) {
      if (message.contains(keyword)) {
        return true;
      }
    }
    
    // 随机回复
    return _random.nextDouble() < _replyProbability;
  }
  
  /// 生成回复
  Future<String?> generateReply(String recentMessage, String senderName) async {
    // 如果没有 LLM 配置，使用后备回复
    if (_llmEndpoint == null || _llmApiKey == null) {
      return _generateFallbackReply(senderName);
    }
    
    try {
      // TODO: 调用实际的 LLM API
      // 目前使用后备回复
      return _generateFallbackReply(senderName);
    } catch (e) {
      debugPrint('[ChatBotService] LLM 生成失败: $e');
      return _generateFallbackReply(senderName);
    }
  }
  
  /// 后备回复（LLM 不可用时）
  String _generateFallbackReply(String senderName) {
    final replies = [
      '嗯嗯，有意思！',
      '哈哈，${senderName}说得好~',
      '这个话题很有意思呢！',
      '我同意${senderName}的看法~',
      '哦？继续说说看？',
      '确实是这样呢~',
      '哈哈，好有趣！',
      '我也这么觉得~',
      '嗯，有道理！',
      '哈哈，你们聊得真开心~',
      '这个我赞同！',
      '说得对~',
      '确实！我也这么想。',
      '有意思，继续~',
      '学习了！',
    ];
    
    return replies[_random.nextInt(replies.length)];
  }
  
  /// 获取回复延迟（模拟思考时间）
  Duration getReplyDelay() {
    final delay = _minReplyDelay + _random.nextInt(_maxReplyDelay - _minReplyDelay);
    return Duration(milliseconds: delay);
  }
}

// 话题记忆压缩服务
//
// 参考 OpenClaw 的 compaction 机制，自动压缩长对话

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../conversation/topic_manager.dart';

/// 记忆压缩服务
class MemoryCompressor {
  final LLMProvider _llmProvider;
  final int maxMessagesBeforeCompress;
  final int targetMessageCount;

  MemoryCompressor({
    required LLMProvider llmProvider,
    this.maxMessagesBeforeCompress = 50,
    this.targetMessageCount = 20,
  }) : _llmProvider = llmProvider;

  /// 压缩话题记忆
  ///
  /// 当消息数超过限制时，将旧消息压缩为摘要
  Future<void> compressTopic(ConversationTopic topic) async {
    if (topic.messages.length <= maxMessagesBeforeCompress) {
      debugPrint('[MemoryCompressor] 话题 ${topic.id} 消息数未超限，跳过压缩');
      return;
    }

    debugPrint('[MemoryCompressor] 开始压缩话题 ${topic.id}，消息数：${topic.messages.length}');

    try {
      // 1. 保留最近的消息
      final recentMessages = topic.messages
          .sublist(topic.messages.length - targetMessageCount);

      // 2. 压缩旧消息
      final oldMessages = topic.messages
          .sublist(0, topic.messages.length - targetMessageCount);

      // 3. 生成摘要
      final summary = await _generateSummary(oldMessages);

      // 4. 保存摘要
      final existingSummary = topic.memorySummary ?? '';
      topic.memorySummary = existingSummary.isEmpty
          ? summary
          : '$existingSummary\n\n---\n\n$summary';

      // 5. 更新消息列表
      topic.messages.clear();
      topic.messages.addAll(recentMessages);

      debugPrint('[MemoryCompressor] 压缩完成，剩余消息数：${topic.messages.length}');
    } catch (e) {
      debugPrint('[MemoryCompressor] 压缩失败: $e');
    }
  }

  /// 生成对话摘要
  Future<String> _generateSummary(List<ChatMessage> messages) async {
    if (messages.isEmpty) {
      return '';
    }

    try {
      // 将消息转换为文本
      final conversationText = messages.map((m) {
        final role = m.role == MessageRole.user ? '用户' : '助手';
        return '$role: ${m.content}';
      }).join('\n');

      final prompt = '''请总结以下对话的主要内容：

$conversationText

要求：
1. 提取关键信息和重要决定
2. 保留具体的数据和事实
3. 使用简洁的语言
4. 不超过 200 字

摘要：''';

      final response = await _llmProvider.generate(
        prompt,
        maxTokens: 300,
      );

      return response.trim();
    } catch (e) {
      debugPrint('[MemoryCompressor] 生成摘要失败: $e');
      return '[压缩失败]';
    }
  }

  /// 检查是否需要压缩
  bool needsCompression(ConversationTopic topic) {
    return topic.messages.length > maxMessagesBeforeCompress;
  }

  /// 获取压缩进度
  double getCompressionProgress(ConversationTopic topic) {
    if (topic.messages.length <= maxMessagesBeforeCompress) {
      return 0;
    }
    return (topic.messages.length - maxMessagesBeforeCompress) /
        maxMessagesBeforeCompress;
  }

  /// 生成关键词标签
  Future<List<String>> generateTags(List<ChatMessage> messages) async {
    if (messages.isEmpty) {
      return [];
    }

    try {
      final conversationText = messages
          .take(5)
          .map((m) {
            final role = m.role == MessageRole.user ? '用户' : '助手';
            return '$role: ${m.content}';
          })
          .join('\n');

      final prompt = '''根据以下对话内容，提取 3-5 个关键词标签：

$conversationText

要求：
1. 每个标签 1-3 个字
2. 用逗号分隔
3. 只返回标签，不要其他内容

标签：''';

      final response = await _llmProvider.generate(
        prompt,
        maxTokens: 50,
      );

      final tags = response
          .split(RegExp(r'[，,\s]+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(5)
          .toList();

      return tags;
    } catch (e) {
      debugPrint('[MemoryCompressor] 生成标签失败: $e');
      return [];
    }
  }

  /// 批量压缩所有需要压缩的话题
  Future<void> compressAllTopics(TopicManager topicManager) async {
    final topicsToCompress = topicManager.activeTopics
        .where((t) => needsCompression(t))
        .toList();

    debugPrint('[MemoryCompressor] 需要压缩的话题数：${topicsToCompress.length}');

    for (final topic in topicsToCompress) {
      await compressTopic(topic);
    }
  }
}

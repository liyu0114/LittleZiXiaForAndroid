// 话题标题生成服务
//
// 使用 LLM 自动生成话题标题

import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../conversation/topic_manager.dart';

/// 话题标题生成器
class TopicTitleGenerator {
  final LLMProvider _llmProvider;

  TopicTitleGenerator({required LLMProvider llmProvider})
      : _llmProvider = llmProvider;

  /// 根据对话内容生成标题
  Future<String> generateTitle(List<ChatMessage> messages) async {
    if (messages.isEmpty) {
      return '新对话';
    }

    try {
      // 取前三条消息作为上下文
      final context = messages.take(3).map((m) {
        final role = m.role == MessageRole.user ? '用户' : '助手';
        return '$role: ${m.content}';
      }).join('\n');

      final prompt = '''根据以下对话内容，生成一个简洁的标题（不超过10个字）：

$context

要求：
1. 准确概括话题主题
2. 简洁明了，不超过10个字
3. 只返回标题，不要其他内容

标题：''';

      final response = await _llmProvider.generate(
        prompt,
        maxTokens: 50,
      );

      final title = response.trim();
      
      // 清理可能的前缀
      final cleanedTitle = title
          .replaceFirst(RegExp(r'^标题[：:]\s*'), '')
          .replaceAll('"', '')
          .trim();

      return cleanedTitle.isNotEmpty ? cleanedTitle : '新对话';
    } catch (e) {
      debugPrint('[TopicTitleGenerator] 生成标题失败: $e');
      return '新对话';
    }
  }

  /// 从消息中提取关键词
  List<String> extractKeywords(List<ChatMessage> messages) {
    final keywords = <String>[];
    final text = messages.map((m) => m.content).join(' ');

    // 简单的关键词提取（实际应用中可以使用更复杂的 NLP）
    final patterns = [
      RegExp(r'养生|健康|锻炼|运动'),
      RegExp(r'股票|投资|理财|基金'),
      RegExp(r'工作|项目|任务'),
      RegExp(r'旅行|旅游|景点'),
      RegExp(r'学习|读书|课程'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) {
        keywords.add(pattern.firstMatch(text)!.group(0)!);
      }
    }

    return keywords;
  }
}

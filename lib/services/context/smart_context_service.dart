// 智能上下文服务
//
// 对标 OpenClaw 的 MEMORY.md + memory_search 机制
// 核心：对话历史自动压缩 + 跨话题记忆搜索 + 动态 System Prompt

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../llm/llm_base.dart';
import '../llm/llm_base.dart' show LLMProvider;

/// 压缩后的对话摘要
class ConversationSummary {
  final String id;
  final String topicId;
  final String summary;
  final List<String> keywords;
  final DateTime createdAt;
  final int originalMessageCount;
  final int originalCharCount;

  ConversationSummary({
    required this.id,
    required this.topicId,
    required this.summary,
    this.keywords = const [],
    DateTime? createdAt,
    this.originalMessageCount = 0,
    this.originalCharCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicId': topicId,
    'summary': summary,
    'keywords': keywords,
    'createdAt': createdAt.toIso8601String(),
    'originalMessageCount': originalMessageCount,
    'originalCharCount': originalCharCount,
  };

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        topicId: json['topicId'] as String,
        summary: json['summary'] as String,
        keywords: List<String>.from(json['keywords'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        originalMessageCount: json['originalMessageCount'] as int? ?? 0,
        originalCharCount: json['originalCharCount'] as int? ?? 0,
      );
}

/// 上下文窗口配置
class SmartContextConfig {
  /// 触发压缩的消息数阈值
  final int compressThreshold;

  /// 压缩后保留的最近消息数
  final int keepRecentCount;

  /// 最大上下文 token 估算值（1 token ≈ 1.5 中文字符）
  final int maxContextTokens;

  /// System Prompt 最大长度
  final int maxSystemPromptChars;

  /// 跨话题搜索返回的最大摘要数
  final int maxRelatedTopics;

  const SmartContextConfig({
    this.compressThreshold = 30,
    this.keepRecentCount = 10,
    this.maxContextTokens = 4000,
    this.maxSystemPromptChars = 2000,
    this.maxRelatedTopics = 3,
  });

  static const SmartContextConfig defaultConfig = SmartContextConfig();
}

/// 智能上下文服务
class SmartContextService extends ChangeNotifier {
  final SmartContextConfig config;
  LLMProvider? _llmProvider;

  // 所有话题的压缩摘要（跨话题记忆）
  final List<ConversationSummary> _summaries = [];

  List<ConversationSummary> get summaries => _summaries;

  SmartContextService({this.config = SmartContextConfig.defaultConfig});

  void initialize(LLMProvider provider) {
    _llmProvider = provider;
  }

  // ==================== Token 估算 ====================

  /// 粗略估算 token 数（中文约 1.5 字符/token，英文约 4 字符/token）
  int estimateTokens(String text) {
    int chineseChars = 0;
    int otherChars = 0;
    for (final char in text.runes) {
      if (char > 0x4E00 && char < 0x9FFF) {
        chineseChars++;
      } else {
        otherChars++;
      }
    }
    return (chineseChars / 1.5).ceil() + (otherChars / 4).ceil();
  }

  /// 估算消息列表的总 token 数
  int estimateMessagesTokens(List<ChatMessage> messages) {
    int total = 0;
    for (final msg in messages) {
      total += estimateTokens(msg.content) + 4; // 每条消息额外 ~4 token 开销
    }
    return total;
  }

  // ==================== 对话历史压缩 ====================

  /// 检查是否需要压缩
  bool shouldCompress(List<ChatMessage> messages) {
    return messages.length >= config.compressThreshold;
  }

  /// 压缩对话历史
  /// 返回压缩后的消息列表（摘要 + 最近消息）
  Future<CompressResult> compressHistory({
    required List<ChatMessage> messages,
    required String topicId,
  }) async {
    if (messages.length < config.compressThreshold) {
      return CompressResult(messages: messages, wasCompressed: false);
    }

    debugPrint('[SmartContext] 开始压缩: ${messages.length} 条消息');

    // 分割：旧消息 → 压缩，新消息 → 保留
    final splitPoint = messages.length - config.keepRecentCount;
    final oldMessages = messages.sublist(0, splitPoint);
    final recentMessages = messages.sublist(splitPoint);

    // 生成摘要
    String summary;
    try {
      summary = await _generateSummary(oldMessages, topicId);
    } catch (e) {
      debugPrint('[SmartContext] LLM 摘要失败，使用简单拼接: $e');
      summary = _simpleSummary(oldMessages);
    }

    // 保存摘要到跨话题记忆
    final convSummary = ConversationSummary(
      id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
      topicId: topicId,
      summary: summary,
      keywords: _extractKeywords(oldMessages),
      originalMessageCount: oldMessages.length,
      originalCharCount: oldMessages.fold(0, (sum, m) => sum + m.content.length),
    );
    _summaries.add(convSummary);
    await _saveSummaries();

    // 构建压缩后的消息列表：system 摘要 + 最近消息
    final compressedMessages = <ChatMessage>[
      ChatMessage.system('之前的对话摘要:\n$summary'),
      ...recentMessages,
    ];

    debugPrint('[SmartContext] 压缩完成: ${messages.length} → ${compressedMessages.length} 条消息');

    return CompressResult(
      messages: compressedMessages,
      wasCompressed: true,
      summary: convSummary,
    );
  }

  /// 用 LLM 生成对话摘要
  Future<String> _generateSummary(List<ChatMessage> messages, String topicId) async {
    if (_llmProvider == null) {
      return _simpleSummary(messages);
    }

    // 构建对话文本（限制长度避免 token 爆炸）
    final buffer = StringBuffer();
    int charCount = 0;
    final maxChars = 8000; // 限制输入长度

    for (final msg in messages) {
      final prefix = msg.role == MessageRole.user ? '用户' : '助手';
      final line = '$prefix: ${msg.content}\n';
      if (charCount + line.length > maxChars) break;
      buffer.writeln(line);
      charCount += line.length;
    }

    final prompt = '''请将以下对话历史压缩为一段简洁的摘要，保留关键信息、决定和结论。用第三人称叙述，200字以内。

对话内容:
${buffer.toString()}

摘要:''' ;

    final response = await _llmProvider!.chat([ChatMessage.user(prompt)]);
    return response.content?.trim() ?? _simpleSummary(messages);
  }

  /// 简单摘要（LLM 不可用时的回退方案）
  String _simpleSummary(List<ChatMessage> messages) {
    final userMsgs = messages.where((m) => m.role == MessageRole.user).toList();
    final topics = userMsgs.map((m) {
      final text = m.content;
      return text.length > 30 ? '${text.substring(0, 30)}...' : text;
    }).toList();

    return '之前讨论了: ${topics.join("、")}（共 ${messages.length} 条消息）';
  }

  /// 从消息中提取关键词
  List<String> _extractKeywords(List<ChatMessage> messages) {
    final allText = messages.map((m) => m.content).join(' ');
    // 简单关键词提取：取高频中文词（2-4字）
    final wordFreq = <String, int>{};
    final regex = RegExp(r'[\u4e00-\u9fff]{2,4}');
    for (final match in regex.allMatches(allText)) {
      final word = match.group(0)!;
      // 过滤停用词
      const stopWords = {'的是', '了一', '然后', '所以', '因为', '但是', '这个', '那个', '什么', '怎么'};
      if (!stopWords.contains(word)) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // 取频率最高的 5 个
    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  // ==================== 跨话题记忆搜索 ====================

  /// 搜索与当前话题相关的历史记忆
  List<ConversationSummary> searchRelatedMemories(String query) {
    if (_summaries.isEmpty) return [];

    final queryLower = query.toLowerCase();
    final scored = <MapEntry<ConversationSummary, double>>[];

    for (final summary in _summaries) {
      double score = 0;

      // 关键词匹配
      for (final keyword in summary.keywords) {
        if (queryLower.contains(keyword.toLowerCase())) {
          score += 2.0;
        }
      }

      // 摘要文本匹配
      if (summary.summary.toLowerCase().contains(queryLower)) {
        score += 1.0;
      }

      // 原始消息内容相关（通过关键词间接匹配）
      final queryWords = queryLower.split(RegExp(r'\s+'));
      for (final word in queryWords) {
        if (word.length >= 2 && summary.summary.toLowerCase().contains(word)) {
          score += 0.5;
        }
      }

      if (score > 0) {
        scored.add(MapEntry(summary, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(config.maxRelatedTopics).map((e) => e.key).toList();
  }

  // ==================== 动态 System Prompt 构建 ====================

  /// 构建包含上下文信息的 System Prompt
  String buildContextualSystemPrompt({
    required String basePrompt,
    String? currentTopicSummary,
    String? memoryContext,
  }) {
    final parts = <String>[basePrompt];

    // 注入当前话题摘要
    if (currentTopicSummary != null && currentTopicSummary.isNotEmpty) {
      parts.add('\n## 当前对话背景\n$currentTopicSummary');
    }

    // 注入相关记忆
    if (memoryContext != null && memoryContext.isNotEmpty) {
      parts.add('\n## 相关历史记忆\n$memoryContext');
    }

    final result = parts.join();
    if (result.length > config.maxSystemPromptChars) {
      return result.substring(0, config.maxSystemPromptChars);
    }
    return result;
  }

  /// 为用户消息构建上下文注入
  /// 搜索相关记忆并附加到消息前
  String buildUserMessageWithContext(String userMessage) {
    final related = searchRelatedMemories(userMessage);
    if (related.isEmpty) return userMessage;

    final contextBuffer = StringBuffer();
    contextBuffer.writeln('[历史对话参考]');
    for (final r in related.take(2)) {
      contextBuffer.writeln('- ${r.summary}');
    }
    contextBuffer.writeln();
    contextBuffer.write(userMessage);

    return contextBuffer.toString();
  }

  // ==================== 上下文窗口管理 ====================

  /// 智能裁剪消息列表，使其符合 token 限制
  /// 策略：保留 system + 最近 N 条 + 压缩旧消息
  List<ChatMessage> fitContextWindow(List<ChatMessage> messages) {
    if (messages.isEmpty) return messages;

    final estimatedTokens = estimateMessagesTokens(messages);
    if (estimatedTokens <= config.maxContextTokens) {
      return messages;
    }

    debugPrint('[SmartContext] 上下文超限: $estimatedTokens tokens，开始裁剪');

    // 分离 system 消息和非 system 消息
    final systemMsgs = messages.where((m) => m.role == MessageRole.system).toList();
    final chatMsgs = messages.where((m) => m.role != MessageRole.system).toList();

    // 从最新的开始保留，直到满足 token 限制
    final result = <ChatMessage>[...systemMsgs];
    int usedTokens = estimateMessagesTokens(systemMsgs);
    int remaining = config.maxContextTokens - usedTokens;

    for (int i = chatMsgs.length - 1; i >= 0 && remaining > 0; i--) {
      final msgTokens = estimateTokens(chatMsgs[i].content) + 4;
      if (usedTokens + msgTokens <= config.maxContextTokens) {
        result.add(chatMsgs[i]);
        usedTokens += msgTokens;
        remaining -= msgTokens;
      } else {
        break;
      }
    }

    // 保持顺序：system 在前，然后按时间顺序
    final nonSystem = result.where((m) => m.role != MessageRole.system).toList();
    return [...systemMsgs, ...nonSystem];
  }

  // ==================== 持久化 ====================

  Future<void> _saveSummaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _summaries.map((s) => s.toJson()).toList();
      await prefs.setString('context_summaries', jsonEncode(json));
    } catch (e) {
      debugPrint('[SmartContext] 保存摘要失败: $e');
    }
  }

  Future<void> loadSummaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('context_summaries');
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        _summaries.clear();
        _summaries.addAll(list.map((j) => ConversationSummary.fromJson(j)));
        debugPrint('[SmartContext] 加载了 ${_summaries.length} 条历史摘要');
      }
    } catch (e) {
      debugPrint('[SmartContext] 加载摘要失败: $e');
    }
  }

  /// 清除所有摘要
  Future<void> clearSummaries() async {
    _summaries.clear();
    await _saveSummaries();
    notifyListeners();
  }
}

/// 压缩结果
class CompressResult {
  final List<ChatMessage> messages;
  final bool wasCompressed;
  final ConversationSummary? summary;

  CompressResult({
    required this.messages,
    required this.wasCompressed,
    this.summary,
  });
}

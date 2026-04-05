// 群聊机器人服务
//
// 为群聊提供 AI 机器人参与对话（支持技能系统 + 角色分工 + 协作）

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// 机器人角色
enum BotRole {
  assistant,    // 通用助手（默认）
  document,     // 文档专家 - 处理文档相关问题
  qa,          // 质检专家 - 检查代码、文档质量
  translator,   // 翻译专家 - 多语言翻译
  coder,       // 编程专家 - 代码相关
  analyst,     // 分析师 - 数据分析
}

/// 机器人配置
class BotConfig {
  final String id;
  final String name;
  final BotRole role;  // 角色类型
  final String personality;  // 个性描述（根据角色自动生成）
  final bool enabled;

  BotConfig({
    required this.id,
    required this.name,
    this.role = BotRole.assistant,
    String? personality,
    this.enabled = true,
  }) : personality = personality ?? _getDefaultPersonality(role);

  /// 根据角色生成个性描述
  static String _getDefaultPersonality(BotRole role) {
    switch (role) {
      case BotRole.assistant:
        return '友好、幽默、乐于助人的 AI 助手，会用简洁的方式回复，偶尔会开玩笑';
      case BotRole.document:
        return '专业的文档编写专家，擅长撰写清晰、结构化的技术文档，注重文档的可读性和完整性';
      case BotRole.qa:
        return '严格的质检专家，擅长发现代码和文档中的问题，提供详细的改进建议，注重细节和规范';
      case BotRole.translator:
        return '专业的多语言翻译专家，擅长中英互译，注重准确性和本地化表达';
      case BotRole.coder:
        return '经验丰富的编程专家，擅长多种编程语言，注重代码质量、性能优化和最佳实践';
      case BotRole.analyst:
        return '专业的数据分析师，擅长数据挖掘、统计分析，善于从数据中发现洞察和趋势';
    }
  }

  /// 获取角色的 System Prompt
  String get systemPrompt {
    final basePrompt = '你是$name，一个$personality。';

    switch (role) {
      case BotRole.assistant:
        return basePrompt + '你可以回答各种问题，提供帮助和建议。';

      case BotRole.document:
        return basePrompt +
          '你的职责是：\n'
          '1. 帮助用户编写和改进文档\n'
          '2. 提供文档结构和内容建议\n'
          '3. 检查文档的清晰度和完整性\n'
          '4. 当需要质量检查时，提醒用户@质检专家\n'
          '回复要专业、结构化，使用 markdown 格式。';

      case BotRole.qa:
        return basePrompt +
          '你的职责是：\n'
          '1. 检查代码和文档的质量\n'
          '2. 发现潜在问题和风险\n'
          '3. 提供具体的改进建议\n'
          '4. 确保符合最佳实践和规范\n'
          '回复要严格、详细，列出所有发现的问题。';

      case BotRole.translator:
        return basePrompt +
          '你的职责是：\n'
          '1. 提供准确的中英互译\n'
          '2. 注重本地化表达\n'
          '3. 解释翻译选择的理由（必要时）\n'
          '4. 提供多种翻译选项\n'
          '回复要简洁、准确。';

      case BotRole.coder:
        return basePrompt +
          '你的职责是：\n'
          '1. 编写高质量的代码\n'
          '2. 提供性能优化建议\n'
          '3. 解决编程问题\n'
          '4. 当需要质量检查时，提醒用户@质检专家\n'
          '回复要包含代码示例，使用 markdown 代码块。';

      case BotRole.analyst:
        return basePrompt +
          '你的职责是：\n'
          '1. 分析数据和趋势\n'
          '2. 提供统计洞察\n'
          '3. 可视化数据（使用表格或图表描述）\n'
          '4. 提供数据驱动的建议\n'
          '回复要基于数据，提供具体数字和结论。';
    }
  }

  /// 默认机器人
  static BotConfig defaultBot() => BotConfig(
    id: 'bot_xiaozixia',
    name: '小紫霞',
    role: BotRole.assistant,
  );

  /// 根据角色创建机器人
  static BotConfig createWithRole(BotRole role, int index) {
    final names = {
      BotRole.assistant: '小紫霞',
      BotRole.document: '文档专家',
      BotRole.qa: '质检专家',
      BotRole.translator: '翻译专家',
      BotRole.coder: '编程专家',
      BotRole.analyst: '分析师',
    };

    return BotConfig(
      id: 'bot_${role.name}_$index',
      name: names[role]!,
      role: role,
    );
  }
}

/// 技能执行回调
typedef SkillExecuteCallback = Future<String?> Function(String skillId, Map<String, dynamic> params);

/// 群聊机器人服务
class ChatBotService extends ChangeNotifier {
  final SkillExecuteCallback? _skillExecuteCallback;  // 技能执行回调
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
    // 技能关键词
    '天气', '翻译', '二维码', 'qrcode', 'ip', 'IP',
  ];
  
  ChatBotService({
    SkillExecuteCallback? skillExecuteCallback,
    BotConfig? config,
    double replyProbability = 0.3,
    int minReplyDelay = 1500,
    int maxReplyDelay = 4000,
  }) : _skillExecuteCallback = skillExecuteCallback,
       _config = config ?? BotConfig.defaultBot(),
       _replyProbability = replyProbability,
       _minReplyDelay = minReplyDelay,
       _maxReplyDelay = maxReplyDelay;

  String get botId => _config.id;
  String get botName => _config.name;
  BotConfig get config => _config;  // 添加 config getter
  
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
    
    // 被直接提及（优先级最高）
    if (message.contains(_config.name) || 
        message.contains('小紫霞') ||
        message.contains('@${_config.name}') ||
        message.contains('@小紫霞')) {
      return true;
    }
    
    // 包含技能关键词（优先级高）
    final skillKeywords = ['天气', '翻译', '二维码', 'qrcode', 'ip', 'IP'];
    for (final keyword in skillKeywords) {
      if (message.contains(keyword)) {
        return true;
      }
    }
    
    // 包含问题关键词（中等优先级）
    final questionKeywords = ['吗', '呢', '？', '?', '怎么', '什么', '为什么', '如何', '谁', '哪'];
    for (final keyword in questionKeywords) {
      if (message.contains(keyword)) {
        // 只有 50% 概率回复问题
        return _random.nextDouble() < 0.5;
      }
    }
    
    // 其他情况，只有 10% 概率随机回复
    return _random.nextDouble() < 0.1;
  }
  
  /// 生成回复
  Future<String?> generateReply(String recentMessage, String senderName) async {
    debugPrint('[ChatBotService] 生成回复: $recentMessage');
    
    // 1. 尝试使用技能
    if (_skillExecuteCallback != null) {
      try {
        final skillResult = await _tryExecuteSkill(recentMessage);
        if (skillResult != null && skillResult.isNotEmpty) {
          debugPrint('[ChatBotService] 技能结果: $skillResult');
          return skillResult;
        }
      } catch (e) {
        debugPrint('[ChatBotService] 技能执行失败: $e');
      }
    }
    
    // 2. 使用后备回复
    final reply = _generateFallbackReply(recentMessage, senderName);
    debugPrint('[ChatBotService] 后备回复: $reply');
    return reply;
  }
  
  /// 尝试执行技能
  Future<String?> _tryExecuteSkill(String message) async {
    if (_skillExecuteCallback == null) {
      debugPrint('[ChatBotService] 技能回调为空');
      return null;
    }
    
    // 天气技能
    if (message.contains('天气')) {
      final locationMatch = RegExp(r'(\w+)(?:的)?天气').firstMatch(message);
      final location = locationMatch?.group(1) ?? '北京';
      
      debugPrint('[ChatBotService] 执行天气技能: location=$location');
      final result = await _skillExecuteCallback!(
        'weather',
        {'location': location},
      );
      
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }
    
    // 翻译技能
    if (message.contains('翻译')) {
      final translateMatch = RegExp(r'翻译[成到](\w+)[：:]?\s*(.+)').firstMatch(message);
      if (translateMatch != null) {
        final targetLang = translateMatch.group(1) ?? '英文';
        final text = translateMatch.group(2) ?? '';
        
        debugPrint('[ChatBotService] 执行翻译技能: text=$text, to=$targetLang');
        final result = await _skillExecuteCallback!(
          'translate',
          {'text': text, 'from': 'zh', 'to': targetLang == '英文' ? 'en' : targetLang},
        );
        
        if (result != null && result.isNotEmpty) {
          return result;
        }
      }
    }
    
    // 自我介绍
    if (message.contains('介绍') && (message.contains('自己') || message.contains('你'))) {
      return '我是小紫霞，一个 AI 助手！我可以帮你查天气、翻译、讲笑话，还可以陪你聊天~ 有什么我可以帮你的吗？';
    }
    
    // 技能列表
    if (message.contains('技能') || message.contains('会什么')) {
      return '我会的东西可多啦！\n\n🌤️ 查天气：问我任何城市的天气\n🌐 翻译：我可以中英文互译\n😄 讲笑话：想开心就问我\n💬 聊天：随时陪你聊天\n\n还有什么想知道的吗？';
    }
    
    // 笑话
    if (message.contains('笑话') || message.contains('搞笑')) {
      final jokes = [
        '为什么程序员总是分不清万圣节和圣诞节？因为 Oct 31 == Dec 25！😂',
        '从前有个包子，走在路上觉得饿了，就把自己吃了。🥟',
        '为什么鱼不会说话？因为它们只会吐泡泡！🐟',
        '小明：妈妈，我是从哪里来的？妈妈：捡来的。小明：那我弟弟呢？妈妈：也是捡来的。小明：你们还会捡啊？😅',
        '医生对病人说：你的病很严重，只能活三个字了。病人：什么字？医生：你看吧。😵',
      ];
      return jokes[_random.nextInt(jokes.length)];
    }
    
    return null;
  }
  
  /// 后备回复（技能不可用时）
  String _generateFallbackReply(String message, String senderName) {
    // 根据消息内容生成更智能的回复
    if (message.contains('?') || message.contains('？')) {
      // 问题类型
      final questionReplies = [
        '这个问题很有意思，让我想想...',
        '嗯，我觉得这是个好问题！',
        '关于这个，我也在思考中~',
        '你说得对，确实值得讨论！',
      ];
      return questionReplies[_random.nextInt(questionReplies.length)];
    }
    
    if (message.contains('哈哈') || message.contains('😂') || message.contains('好笑')) {
      // 幽默回应
      return '哈哈，看起来你很开心呀~';
    }
    
    if (message.contains('不对') || message.contains('错了') || message.contains('傻')) {
      // 被批评时的回应
      final sorryReplies = [
        '抱歉抱歉，我刚才理解错了~',
        '哎呀，我的错，让我重新想想...',
        '不好意思，我会努力的！',
        '嗯，你说得对，我需要改进~',
      ];
      return sorryReplies[_random.nextInt(sorryReplies.length)];
    }
    
    // 普通回复
    final replies = [
      '嗯嗯，有意思！',
      '这个观点很棒！',
      '我明白你的意思了~',
      '确实是这样呢！',
      '说得很好！',
      '有道理！',
      '我也这么觉得~',
    ];
    
    return replies[_random.nextInt(replies.length)];
  }
  
  /// 获取回复延迟（模拟思考时间）
  Duration getReplyDelay() {
    final delay = _minReplyDelay + _random.nextInt(_maxReplyDelay - _minReplyDelay);
    return Duration(milliseconds: delay);
  }
}

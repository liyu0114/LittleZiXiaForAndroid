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

/// LLM 生成回调
typedef LLMGenerateCallback = Future<String?> Function(String message, List<Map<String, String>> history);

/// 群聊机器人服务
class ChatBotService extends ChangeNotifier {
  final SkillExecuteCallback? _skillExecuteCallback;  // 技能执行回调
  final LLMGenerateCallback? _llmGenerateCallback;    // LLM 生成回调（优先使用）
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
    LLMGenerateCallback? llmGenerateCallback,  // 新增：LLM 生成回调
    BotConfig? config,
    double replyProbability = 0.3,
    int minReplyDelay = 1500,
    int maxReplyDelay = 4000,
  }) : _skillExecuteCallback = skillExecuteCallback,
       _llmGenerateCallback = llmGenerateCallback,
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

    final lowerMessage = message.toLowerCase();

    // 被直接提及（优先级最高，必须回复）
    if (message.contains(_config.name) ||
        message.contains('小紫霞') ||
        message.contains('@${_config.name}') ||
        message.contains('@小紫霞')) {
      debugPrint('[ChatBotService] 被直接提及，必须回复');
      return true;
    }

    // 包含技能关键词（优先级高，应该回复）
    final skillKeywords = ['天气', '翻译', '二维码', 'qrcode', 'ip', 'IP', '笑话', '故事'];
    for (final keyword in skillKeywords) {
      if (lowerMessage.contains(keyword.toLowerCase())) {
        debugPrint('[ChatBotService] 技能关键词触发: $keyword');
        return true;
      }
    }

    // 包含问题关键词（中等优先级，提高到 80%）
    final questionKeywords = ['吗', '呢', '？', '?', '怎么', '什么', '为什么', '如何', '谁', '哪', '能否', '可以'];
    for (final keyword in questionKeywords) {
      if (message.contains(keyword)) {
        // 问题有 80% 概率回复（提高到 80%）
        final shouldReplyQuestion = _random.nextDouble() < 0.8;
        debugPrint('[ChatBotService] 问题关键词: $keyword, 是否回复: $shouldReplyQuestion');
        return shouldReplyQuestion;
      }
    }

    // 其他情况，提高到 20% 概率随机回复
    final shouldReplyRandom = _random.nextDouble() < 0.2;
    debugPrint('[ChatBotService] 随机回复概率: $shouldReplyRandom');
    return shouldReplyRandom;
  }

  /// 生成回复
  Future<String?> generateReply(String recentMessage, String senderName) async {
    debugPrint('[ChatBotService] ========== 生成回复 ==========');
    debugPrint('[ChatBotService] 发送者: $senderName');
    debugPrint('[ChatBotService] 消息: $recentMessage');
    debugPrint('[ChatBotService] 角色配置: ${_config.role}');
    debugPrint('[ChatBotService] 对话历史长度: ${_conversationHistory.length}');
    debugPrint('[ChatBotService] LLM 回调: ${_llmGenerateCallback != null ? "已设置" : "未设置"}');

    // 1. 尝试使用技能（特定技能优先）
    if (_skillExecuteCallback != null) {
      try {
        debugPrint('[ChatBotService] 尝试执行技能...');
        final skillResult = await _tryExecuteSkill(recentMessage);
        if (skillResult != null && skillResult.isNotEmpty) {
          debugPrint('[ChatBotService] ✅ 技能结果: $skillResult');
          return skillResult;
        }
      } catch (e) {
        debugPrint('[ChatBotService] ❌ 技能执行失败: $e');
      }
    } else {
      debugPrint('[ChatBotService] ⚠️ 技能回调未设置');
    }

    // 2. 【优先】调用 LLM 生成回复
    if (_llmGenerateCallback != null) {
      try {
        debugPrint('[ChatBotService] 调用 LLM 生成回复...');
        final llmResponse = await _llmGenerateCallback!(
          recentMessage,
          List.from(_conversationHistory),
        );
        if (llmResponse != null && llmResponse.isNotEmpty) {
          debugPrint('[ChatBotService] ✅ LLM 回复: $llmResponse');
          return llmResponse;
        }
      } catch (e) {
        debugPrint('[ChatBotService] ❌ LLM 生成失败: $e');
      }
    } else {
      debugPrint('[ChatBotService] ⚠️ LLM 回调未设置，使用后备回复');
    }
    
    // 3. 【后备】使用硬编码回复（仅在 LLM 不可用时）
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
    
    // 1. 数学计算（优先处理）
    final mathResult = _tryMathCalculation(message);
    if (mathResult != null) {
      return mathResult;
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
  
  /// 尝试数学计算
  String? _tryMathCalculation(String message) {
    // 清理消息
    final cleanMessage = message.trim();
    
    // 匹配简单数学表达式：数字 运算符 数字
    final mathPattern = RegExp(r'(\d+(?:\.\d+)?)\s*([+\-×÷*\/xX])\s*(\d+(?:\.\d+)?)');
    final match = mathPattern.firstMatch(cleanMessage);
    
    if (match != null) {
      try {
        final num1 = double.parse(match.group(1)!);
        final operator = match.group(2)!;
        final num2 = double.parse(match.group(3)!);
        
        double result;
        String operatorSymbol;
        
        switch (operator) {
          case '+':
            result = num1 + num2;
            operatorSymbol = '+';
            break;
          case '-':
            result = num1 - num2;
            operatorSymbol = '-';
            break;
          case '*':
          case 'x':
          case 'X':
          case '×':
            result = num1 * num2;
            operatorSymbol = '×';
            break;
          case '/':
          case '÷':
            if (num2 == 0) {
              return '除数不能为 0 哦~';
            }
            result = num1 / num2;
            operatorSymbol = '÷';
            break;
          default:
            return null;
        }
        
        // 格式化结果（整数不显示小数点）
        final num1Str = num1 == num1.toInt() ? num1.toInt().toString() : num1.toString();
        final num2Str = num2 == num2.toInt() ? num2.toInt().toString() : num2.toString();
        final resultStr = result == result.toInt() ? result.toInt().toString() : result.toStringAsFixed(2);
        
        return '$num1Str $operatorSymbol $num2Str = $resultStr 🧮';
      } catch (e) {
        debugPrint('[ChatBotService] 数学计算失败: $e');
        return null;
      }
    }
    
    return null;
  }
  
  /// 后备回复（技能不可用时）
  String _generateFallbackReply(String message, String senderName) {
    debugPrint('[ChatBotService] 使用后备回复，角色: ${_config.role}');

    // 根据角色生成特定回复
    String reply;

    switch (_config.role) {
      case BotRole.assistant:
        reply = _generateAssistantReply(message, senderName);
        break;
      case BotRole.document:
        reply = _generateDocumentReply(message, senderName);
        break;
      case BotRole.qa:
        reply = _generateQAReply(message, senderName);
        break;
      case BotRole.translator:
        reply = _generateTranslatorReply(message, senderName);
        break;
      case BotRole.coder:
        reply = _generateCoderReply(message, senderName);
        break;
      case BotRole.analyst:
        reply = _generateAnalystReply(message, senderName);
        break;
    }

    debugPrint('[ChatBotService] 后备回复: $reply');
    return reply;
  }

  /// 通用助手回复
  String _generateAssistantReply(String message, String senderName) {
    // 1. 分析消息类型和意图
    final messageLower = message.toLowerCase();

    // 2. 基于消息内容生成特定回复
    
    // 能力询问（你会...吗？）
    if (message.contains('会') && (message.contains('吗') || message.contains('?') || message.contains('？'))) {
      if (message.contains('开发') || message.contains('编程') || message.contains('写代码')) {
        return '是的，我会编程！我可以帮你写代码、改bug、优化性能，有什么编程方面的问题都可以问我~';
      } else if (message.contains('翻译')) {
        return '当然！我会中英文互译，你可以直接告诉我要翻译的内容~';
      } else if (message.contains('天气')) {
        return '会的！我可以查询任何城市的天气，你只需要告诉我城市名~';
      } else if (message.contains('聊天') || message.contains('对话')) {
        return '当然会！我随时可以陪你聊天，有什么想说的都可以告诉我~';
      } else {
        return '嗯，这个要看具体情况了。你具体想问我什么呢？';
      }
    }

    if (message.contains('?') || message.contains('？')) {
      // 问题类型 - 根据问题内容生成回复
      if (message.contains('什么') || message.contains('是什么')) {
        return '关于这个问题，让我为你解释一下。${_getContextualResponse(message)}';
      } else if (message.contains('怎么') || message.contains('如何')) {
        return '这个问题很好！${_getContextualResponse(message)}';
      } else if (message.contains('为什么')) {
        return '这是一个值得深思的问题。${_getContextualResponse(message)}';
      } else if (message.contains('吗')) {
        // 是非问题 - 尝试给出明确答案
        if (message.contains('能') || message.contains('可以') || message.contains('会')) {
          final positiveReplies = [
            '是的，可以的~',
            '没问题，我能做到~',
            '当然可以！',
            '嗯，这个我可以帮你~',
          ];
          return positiveReplies[_random.nextInt(positiveReplies.length)];
        } else {
          final yesNoReplies = [
            '根据我的理解，应该是的~',
            '嗯，这个问题要看具体情况呢~',
            '让我想想...我觉得可以这样理解~',
          ];
          return yesNoReplies[_random.nextInt(yesNoReplies.length)];
        }
      } else {
        final questionReplies = [
          '这个问题很有意思，让我想想...',
          '嗯，我觉得这是个好问题！',
          '关于这个，我也在思考中~',
        ];
        return questionReplies[_random.nextInt(questionReplies.length)];
      }
    }

    if (message.contains('哈哈') || message.contains('😂') || message.contains('好笑')) {
      return '哈哈，看起来你很开心呀~ 有什么有趣的事情吗？';
    }

    if (message.contains('不对') || message.contains('错了') || message.contains('傻') || message.contains('答非所问')) {
      final sorryReplies = [
        '抱歉抱歉，我刚才理解错了~ 让我重新回答你的问题。',
        '哎呀，我的错！你的问题是关于什么的呢？',
        '不好意思，我会注意的！请再问我一次好吗？',
      ];
      return sorryReplies[_random.nextInt(sorryReplies.length)];
    }

    // 3. 根据对话历史生成上下文相关回复
    if (_conversationHistory.length > 2) {
      final lastMsg = _conversationHistory[_conversationHistory.length - 1];
      final lastContent = lastMsg['content'] as String;

      // 如果上一条消息是问题，尝试延续对话
      if (lastContent.contains('?') || lastContent.contains('？')) {
        return '接着刚才的话题，${_getContextualResponse(message)}';
      }
    }

    // 4. 默认回复
    final replies = [
      '嗯嗯，有意思！',
      '这个观点很棒！',
      '我明白你的意思了~',
      '确实是这样呢！',
      '说得很好！',
    ];
    return replies[_random.nextInt(replies.length)];
  }

  /// 获取上下文相关的回复
  String _getContextualResponse(String message) {
    // 基于消息关键词生成相关回复
    if (message.contains('天气')) {
      return '如果你想了解天气，可以问我"北京天气怎么样"~';
    } else if (message.contains('翻译')) {
      return '如果需要翻译，可以说"翻译成英文：你好"';
    } else if (message.contains('笑话')) {
      return '想听笑话？没问题，问我"讲个笑话"~';
    } else if (message.contains('开发') || message.contains('编程')) {
      return '关于编程方面，我可以帮你写代码、改bug、优化性能~';
    } else {
      return '我在这里陪你聊天，有什么都可以问我~';
    }
  }

  /// 文档专家回复
  String _generateDocumentReply(String message, String senderName) {
    if (message.contains('文档') || message.contains('写')) {
      return '关于文档方面，我可以帮你：\n1. 梳理文档结构\n2. 优化表达方式\n3. 检查完整性\n需要我帮忙吗？';
    }
    return '作为文档专家，我建议保持文档的清晰和结构化~';
  }

  /// 质检专家回复
  String _generateQAReply(String message, String senderName) {
    if (message.contains('检查') || message.contains('问题')) {
      return '让我来帮你检查一下，我关注以下几个方面：\n1. 代码质量\n2. 潜在风险\n3. 最佳实践';
    }
    return '质检角度：确保质量和规范是成功的关键~';
  }

  /// 翻译专家回复
  String _generateTranslatorReply(String message, String senderName) {
    if (message.contains('翻译') || message.contains('英文')) {
      return '需要翻译什么内容？我可以提供准确的中英互译~';
    }
    return '作为翻译专家，我注重准确性和本地化表达~';
  }

  /// 编程专家回复
  String _generateCoderReply(String message, String senderName) {
    if (message.contains('代码') || message.contains('bug') || message.contains('Bug')) {
      return '编程方面的问题？我可以帮你：\n1. 写代码\n2. 性能优化\n3. Bug 排查';
    }
    return '作为编程专家，代码质量和最佳实践是我的追求~';
  }

  /// 分析师回复
  String _generateAnalystReply(String message, String senderName) {
    if (message.contains('数据') || message.contains('分析')) {
      return '数据分析方面，我可以帮你：\n1. 数据趋势分析\n2. 统计洞察\n3. 可视化建议';
    }
    return '从数据角度看，一切都要有理有据~';
  }
  
  /// 获取回复延迟（模拟思考时间）
  Duration getReplyDelay() {
    final delay = _minReplyDelay + _random.nextInt(_maxReplyDelay - _minReplyDelay);
    return Duration(milliseconds: delay);
  }
}

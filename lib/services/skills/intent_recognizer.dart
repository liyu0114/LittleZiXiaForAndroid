// 意图识别服务
//
// 使用 LLM 识别用户意图并提取 Skill 参数

import 'dart:convert';
import '../llm/llm_base.dart';
import '../llm/llm_factory.dart';

/// 意图识别结果
class IntentResult {
  final String? skillId;      // 匹配的 Skill ID（null 表示没有匹配）
  final Map<String, dynamic> params;  // 提取的参数
  final double confidence;    // 置信度 (0.0-1.0)
  final String? rawResponse;  // LLM 原始响应

  IntentResult({
    this.skillId,
    this.params = const {},
    this.confidence = 0.0,
    this.rawResponse,
  });

  bool get hasIntent => skillId != null && confidence > 0.5;

  factory IntentResult.fromJson(Map<String, dynamic> json) {
    return IntentResult(
      skillId: json['intent'] as String?,
      params: Map<String, dynamic>.from(json['params'] ?? {}),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawResponse: jsonEncode(json),
    );
  }

  @override
  String toString() {
    return 'IntentResult(skillId: $skillId, params: $params, confidence: $confidence)';
  }
}

/// 意图识别服务
class IntentRecognizer {
  final LLMProvider _llmProvider;
  
  // 可用的 Skill 列表
  static const Map<String, Map<String, String>> _availableSkills = {
    'weather': {
      'name': '天气查询',
      'description': '查询指定城市的天气情况',
      'params': 'location (城市名)',
    },
    'translate': {
      'name': '翻译',
      'description': '将文本翻译成目标语言',
      'params': 'text (待翻译文本), target_lang (目标语言，如 en、ja、ko)',
    },
    'web_search': {
      'name': '网页搜索',
      'description': '在网络上搜索信息',
      'params': 'query (搜索关键词)',
    },
    'calculator': {
      'name': '计算器',
      'description': '执行数学计算',
      'params': 'expression (数学表达式)',
    },
    'reminder': {
      'name': '提醒',
      'description': '设置定时提醒',
      'params': 'time (提醒时间), content (提醒内容)',
    },
    'time': {
      'name': '时间查询',
      'description': '查询当前时间、日期、星期几',
      'params': '无',
    },
    'timer': {
      'name': '倒计时',
      'description': '设置倒计时',
      'params': 'duration (时长，如 5分钟、10秒)',
    },
  };

  IntentRecognizer(this._llmProvider);

  /// 识别用户消息的意图
  Future<IntentResult> recognize(String userMessage) async {
    // 构建提示词
    final prompt = _buildPrompt(userMessage);

    // 调用 LLM
    try {
      final messages = [
        ChatMessage.system(prompt),
        ChatMessage.user(userMessage),
      ];

      // 使用非流式调用获取完整响应
      final response = await _callLLM(messages);
      
      // 解析 JSON
      return _parseResponse(response);
    } catch (e) {
      print('[IntentRecognizer] 意图识别失败: $e');
      return IntentResult(confidence: 0.0);
    }
  }

  /// 构建 LLM 提示词
  String _buildPrompt(String userMessage) {
    final skillsDescription = _availableSkills.entries.map((entry) {
      final skill = entry.value;
      return '- ${entry.key}: ${skill['name']} - ${skill['description']}（参数：${skill['params']}）';
    }).join('\n');

    return '''
你是一个意图识别助手。请分析用户的消息，识别意图并提取参数。

可用的 Skill：
$skillsDescription

用户消息：$userMessage

请以 JSON 格式返回：
{
  "intent": "skill_id 或 null",
  "params": {
    "param_name": "param_value"
  },
  "confidence": 0.0-1.0
}

规则：
1. 如果用户消息匹配某个 Skill，返回对应的 skill_id
2. 提取所有必要的参数（如果参数缺失，设为 null）
3. confidence 表示匹配置信度（0.0-1.0）
4. 如果没有匹配的 Skill，返回 {"intent": null, "params": {}, "confidence": 0.0}
5. 只返回 JSON，不要有其他文字

示例：
用户："北京今天天气怎么样"
返回：{"intent": "weather", "params": {"location": "北京"}, "confidence": 0.95}

用户："帮我翻译成英文：你好世界"
返回：{"intent": "translate", "params": {"text": "你好世界", "target_lang": "en"}, "confidence": 0.9}

用户："帮我搜索一下 Flutter 教程"
返回：{"intent": "web_search", "params": {"query": "Flutter 教程"}, "confidence": 0.9}

用户："今天天气不错"
返回：{"intent": null, "params": {}, "confidence": 0.0}

现在请分析用户消息并返回 JSON：
''';
  }

  /// 调用 LLM（非流式）
  Future<String> _callLLM(List<ChatMessage> messages) async {
    final buffer = StringBuffer();
    final stream = _llmProvider.chatStream(messages);

    await for (final event in stream) {
      if (event.error != null) {
        throw Exception(event.error);
      }
      if (event.done) {
        break;
      }
      if (event.delta != null) {
        buffer.write(event.delta);
      }
    }

    return buffer.toString();
  }

  /// 解析 LLM 响应
  IntentResult _parseResponse(String response) {
    try {
      // 提取 JSON（可能被 ```json ... ``` 包裹）
      var jsonStr = response.trim();
      
      // 移除 markdown 代码块标记
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      
      jsonStr = jsonStr.trim();

      // 解析 JSON
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      return IntentResult.fromJson(json);
    } catch (e) {
      print('[IntentRecognizer] JSON 解析失败: $e');
      print('[IntentRecognizer] 原始响应: $response');
      return IntentResult(confidence: 0.0);
    }
  }

  /// 快速检测（不使用 LLM，用于简单场景）
  /// 
  /// 这个方法用于在没有 LLM 或需要快速响应时使用
  static IntentResult quickDetect(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // 天气
    if (lowerMessage.contains('天气') ||
        lowerMessage.contains('weather') ||
        lowerMessage.contains('气温') ||
        lowerMessage.contains('温度')) {
      final location = _extractCity(userMessage);
      return IntentResult(
        skillId: 'weather',
        params: location != null ? {'location': location} : {},
        confidence: 0.8,
      );
    }

    // 翻译
    if (lowerMessage.contains('翻译') || lowerMessage.contains('translate')) {
      // 提取待翻译文本
      final match = RegExp(r'翻译[成到]?\s*([a-z]+)?[：:]\s*(.+)').firstMatch(userMessage);
      if (match != null) {
        return IntentResult(
          skillId: 'translate',
          params: {
            'text': match.group(2),
            'target_lang': match.group(1) ?? 'en',
          },
          confidence: 0.9,
        );
      }
    }

    // 搜索
    if (lowerMessage.contains('搜索') ||
        lowerMessage.contains('search') ||
        lowerMessage.contains('查一下') ||
        lowerMessage.contains('查查')) {
      final match = RegExp(r'(?:搜索|查一下|查查)\s*(.+)').firstMatch(userMessage);
      if (match != null) {
        return IntentResult(
          skillId: 'web_search',
          params: {'query': match.group(1)},
          confidence: 0.85,
        );
      }
    }

    // 计算
    if (lowerMessage.contains('计算') ||
        lowerMessage.contains('calculate') ||
        RegExp(r'\d+\s*[\+\-\*\/]\s*\d+').hasMatch(userMessage)) {
      final match = RegExp(r'[\d\+\-\*\/\(\)\.]+').firstMatch(userMessage);
      if (match != null) {
        return IntentResult(
          skillId: 'calculator',
          params: {'expression': match.group(0)},
          confidence: 0.9,
        );
      }
    }

    // 时间
    if (lowerMessage.contains('几点') ||
        lowerMessage.contains('时间') ||
        lowerMessage.contains('time') ||
        lowerMessage.contains('星期几') ||
        lowerMessage.contains('日期')) {
      return IntentResult(
        skillId: 'time',
        params: {},
        confidence: 0.95,
      );
    }

    // 没有匹配
    return IntentResult(confidence: 0.0);
  }

  /// 提取城市名（用于快速检测）
  static String? _extractCity(String message) {
    final cities = [
      '北京', '上海', '广州', '深圳', '杭州', '成都', '武汉', '西安',
      '南京', '天津', '重庆', '苏州', '郑州', '长沙', '沈阳', '青岛',
      '南宁', '昆明', '贵阳', '海口', '兰州', '银川', '西宁', '石家庄',
      '太原', '济南', '合肥', '福州', '南昌', '长春', '哈尔滨', '呼和浩特',
      '乌鲁木齐', '拉萨', '大连', '宁波', '厦门', '深圳', '珠海', '东莞',
    ];

    for (final city in cities) {
      if (message.contains(city)) {
        return city;
      }
    }

    // 尝试提取"XX市"或"XX的天气"模式
    final cityPattern1 = RegExp(r'([^\s]+)市');
    final cityPattern2 = RegExp(r'([^\s]+)的天气');
    final match1 = cityPattern1.firstMatch(message);
    final match2 = cityPattern2.firstMatch(message);

    if (match1 != null) {
      return match1.group(1);
    } else if (match2 != null) {
      return match2.group(1);
    }

    return null;
  }
}

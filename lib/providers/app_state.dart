// 应用状态管理
//
// 管理 LLM 配置、能力层、对话历史、Skills、远程连接、话题

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import '../services/llm/llm_base.dart';
import '../services/llm/llm_factory.dart';
import '../services/capabilities/capability_manager.dart';
import '../services/skills/skill_system.dart';
import '../services/skills/intent_recognizer.dart';
import '../services/skills/skill_summarizer.dart';
import '../services/remote/remote_connection.dart';
import '../services/voice/tts_service.dart';
import '../services/file/file_picker_service.dart';
import '../services/conversation/topic_manager.dart';
import '../widgets/task_list.dart';

/// 对话消息（UI 层使用）
class ConversationMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? error;

  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  ConversationMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? error,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
    );
  }
}

/// 应用状态
class AppState extends ChangeNotifier {
  final Logger _logger = Logger();

  // LLM 相关
  LLMConfig? _llmConfig;
  LLMProvider? _llmProvider;
  bool _isGenerating = false;
  String? _error;

  // 对话历史
  final List<ConversationMessage> _messages = [];
  final List<ChatMessage> _llmMessages = [];
  int _messageIndex = 0;

  // 话题管理（学习 DeepSeek）
  late TopicManager _topicManager;

  // Skill 系统
  late SkillManager _skillManager;
  SkillSummarizer? _skillSummarizer;

  // 语音合成（TTS）
  late TTSService _ttsService;

  // 自定义 Skills
  List<CustomSkill> _customSkills = [];
  List<CustomSkill> get customSkills => _customSkills;

  // 远程连接
  RemoteConnection? _remoteConnection;

  // 能力层
  CapabilityConfig _capabilityConfig = CapabilityConfig();
  late CapabilityManager _capabilityManager;

  // 任务管理
  final List<TaskInfo> _tasks = [];
  final Map<String, Timer> _taskTimers = {};

  // 会话管理
  final List<SessionInfo> _sessions = [];

  // Getters
  LLMConfig? get llmConfig => _llmConfig;
  bool get hasLLMConfig => _llmConfig != null && _llmConfig!.apiKey.isNotEmpty;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  TopicManager get topicManager => _topicManager;
  SkillRegistry get skillRegistry => _skillManager.registry;
  TTSService get ttsService => _ttsService;
  RemoteConnection? get remoteConnection => _remoteConnection;
  bool get isRemoteConnected => _remoteConnection?.isConnected ?? false;
  CapabilityConfig get capabilityConfig => _capabilityConfig;
  CapabilityManager get capabilityManager => _capabilityManager;
  List<TaskInfo> get tasks => List.unmodifiable(_tasks);
  List<TaskInfo> get activeTasks => _tasks.where((t) => t.status == TaskStatus.running).toList();
  List<SessionInfo> get sessions => List.unmodifiable(_sessions);

  AppState() {
    _capabilityManager = CapabilityManager(config: _capabilityConfig);
    _skillManager = SkillManager();
    _topicManager = TopicManager();

    // 初始化 TTS
    _ttsService = TTSService();

    // 异步加载 Skills 和 话题
    _initializeSkills();
    _initializeTopics();

    _loadConfig();
  }

  /// 初始化 Skills
  Future<void> _initializeSkills() async {
    await _skillManager.initialize();
    notifyListeners();
  }

  /// 初始化话题
  Future<void> _initializeTopics() async {
    await _topicManager.load();
    // 如果没有当前话题，创建一个新的
    if (_topicManager.currentTopic == null) {
      _topicManager.createTopic();
    }
    notifyListeners();
  }

  /// 加载自定义 Skills
  Future<void> _loadCustomSkills() async {
    try {
      if (_llmProvider == null) {
        print('[DEBUG] LLM Provider 未初始化，跳过加载自定义 Skills');
        return;
      }
      
      _skillSummarizer = SkillSummarizer(_llmProvider!);
      _customSkills = await _skillSummarizer!.loadCustomSkills();
      notifyListeners();
      print('[DEBUG] 已加载 ${_customSkills.length} 个自定义 Skills');
    } catch (e) {
      print('[DEBUG] 加载自定义 Skills 失败: $e');
    }
  }

  /// 从对话中总结 Skill
  Future<CustomSkill?> summarizeSkillFromConversation() async {
    if (_llmProvider == null) {
      _error = '请先配置大模型';
      notifyListeners();
      return null;
    }

    if (_skillSummarizer == null) {
      _error = 'Skill 总结服务未初始化';
      notifyListeners();
      return null;
    }

    try {
      // 准备对话历史（最近 10 条）
      final recentMessages = _llmMessages.take(10).map((msg) {
        return {
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        };
      }).toList();

      if (recentMessages.isEmpty) {
        _error = '对话历史为空，无法总结';
        notifyListeners();
        return null;
      }

      print('[DEBUG] 开始总结 Skill，对话历史: ${recentMessages.length} 条');

      // 调用总结服务
      final skill = await _skillSummarizer!.summarizeFromConversation(recentMessages);

      if (skill != null) {
        // 保存到本地
        await _skillSummarizer!.saveCustomSkill(skill);
        
        // 添加到内存
        _customSkills.add(skill);
        notifyListeners();
        
        print('[DEBUG] 成功总结并保存 Skill: ${skill.name}');
        return skill;
      } else {
        _error = '没有识别到可复用的模式';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = '总结失败: $e';
      notifyListeners();
      print('[DEBUG] 总结失败: $e');
      return null;
    }
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载 LLM 配置
    final llmConfigJson = prefs.getString('llm_config');
    if (llmConfigJson != null) {
      try {
        _llmConfig = LLMConfig.fromJson(jsonDecode(llmConfigJson));
        _llmProvider = LLMFactory.create(_llmConfig!);
      } catch (e) {
        _logger.e('加载 LLM 配置失败: $e');
      }
    }

    // 加载能力配置
    final capabilityConfigJson = prefs.getString('capability_config');
    if (capabilityConfigJson != null) {
      try {
        _capabilityConfig = CapabilityConfig.fromJson(jsonDecode(capabilityConfigJson));
        _capabilityManager = CapabilityManager(config: _capabilityConfig);
      } catch (e) {
        _logger.e('加载能力配置失败: $e');
      }
    }

    // 加载对话历史
    final historyJson = prefs.getString('conversation_history');
    if (historyJson != null) {
      try {
        final history = jsonDecode(historyJson) as List;
        for (final item in history) {
          _messages.add(ConversationMessage(
            id: item['id'],
            role: MessageRole.values.firstWhere((r) => r.name == item['role']),
            content: item['content'],
            timestamp: DateTime.parse(item['timestamp']),
          ));
        }
      } catch (e) {
        _logger.e('加载对话历史失败: $e');
      }
    }

    notifyListeners();
    
    // 加载自定义 Skills（在配置加载完成后）
    _loadCustomSkills();
  }

  /// 保存 LLM 配置
  Future<void> saveLLMConfig(LLMConfig config) async {
    _llmConfig = config;
    _llmProvider = LLMFactory.create(config);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_config', jsonEncode(config.toJson()));

    notifyListeners();
  }

  /// 更新能力配置
  Future<void> updateCapabilityConfig(CapabilityConfig config) async {
    _capabilityConfig = config;
    _capabilityManager = CapabilityManager(config: config);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('capability_config', jsonEncode(config.toJson()));

    notifyListeners();
  }

  /// 发送消息（使用智能 Skill 系统）
  Future<void> sendMessage(String content, {String? imagePath, String? videoPath, FilePickResult? fileResult}) async {
    if (content.trim().isEmpty && imagePath == null && videoPath == null && fileResult == null) return;
    if (_llmProvider == null) {
      _error = '请先配置大模型';
      notifyListeners();
      return;
    }

    // 构建显示内容
    String displayContent = content;
    if (imagePath != null) {
      displayContent = '$content\n[图像: $imagePath]';
    }
    if (videoPath != null) {
      displayContent = '$content\n[视频: $videoPath]';
    }
    if (fileResult != null) {
      displayContent = '$content\n[文件: ${fileResult.name} (${fileResult.sizeFormatted})]';
    }

    // 添加用户消息
    final userMsg = ConversationMessage(
      id: 'user_${_messageIndex++}',
      role: MessageRole.user,
      content: displayContent,
    );
    _messages.add(userMsg);
    
    // 构建 LLM 消息
    String llmContent = content;
    if (imagePath != null) {
      llmContent = '[用户发送了一张图像]\n$content';
      // TODO: 支持 Vision LLM（通义千问 VL）
    }
    if (videoPath != null) {
      llmContent = '[用户发送了一段视频（15秒以内）]\n$content';
      // TODO: 支持 Video LLM
    }
    if (fileResult != null) {
      llmContent = '[用户发送了一个文件：${fileResult.name}]\n$content';
      // TODO: 支持 Document LLM
    }
    
    _llmMessages.add(ChatMessage.user(llmContent));

    print('[DEBUG] ========== 智能意图识别开始 ==========');
    String? skillResponse;

    try {
      // 创建意图识别器
      final recognizer = IntentRecognizer(_llmProvider!);
      
      // 使用 LLM 识别意图
      print('[DEBUG] 使用 LLM 识别意图...');
      final intent = await recognizer.recognize(content);
      
      print('[DEBUG] 意图识别结果: $intent');

      // 如果识别到 Skill 意图
      if (intent.hasIntent) {
        print('[DEBUG] ✓ 识别到 Skill: ${intent.skillId}');
        print('[DEBUG] 参数: ${intent.params}');

        // 执行 Skill
        skillResponse = await _executeSkillById(intent.skillId!, intent.params);
      } else {
        print('[DEBUG] ✗ 没有识别到 Skill 意图，调用 LLM');
      }
    } catch (e) {
      print('[DEBUG] 意图识别出错: $e');
      // 出错时回退到快速检测
      final quickIntent = IntentRecognizer.quickDetect(content);
      if (quickIntent.hasIntent) {
        print('[DEBUG] 快速检测到 Skill: ${quickIntent.skillId}');
        skillResponse = await _executeSkillById(quickIntent.skillId!, quickIntent.params);
      }
    }

    // 如果 Skill 有响应，直接返回
    if (skillResponse != null) {
      final assistantMsg = ConversationMessage(
        id: 'assistant_${_messageIndex++}',
        role: MessageRole.assistant,
        content: skillResponse,
      );
      _messages.add(assistantMsg);
      notifyListeners();

      // 自动播放语音回复
      _speakResponse(skillResponse);

      return;
    }

    // 否则，调用 LLM
    print('[DEBUG] 调用 LLM 生成回复...');

    // 添加空的助手消息（用于流式填充）
    final assistantIndex = _messages.length;
    final assistantMsg = ConversationMessage(
      id: 'assistant_${_messageIndex++}',
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    _messages.add(assistantMsg);

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final stream = _llmProvider!.chatStream(_llmMessages);
      final buffer = StringBuffer();

      await for (final event in stream) {
        if (event.error != null) {
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: buffer.toString(),
            isStreaming: false,
            error: event.error,
          );
          break;
        }

        if (event.done) {
          final responseText = buffer.toString();
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: responseText,
            isStreaming: false,
          );

          // 自动播放语音回复
          _speakResponse(responseText);

          break;
        }

        if (event.delta != null) {
          buffer.write(event.delta);
          _messages[assistantIndex] = _messages[assistantIndex].copyWith(
            content: buffer.toString(),
          );
          notifyListeners();
        }
      }

      _llmMessages.add(ChatMessage.assistant(buffer.toString()));
      await _saveConversationHistory();
    } catch (e) {
      _logger.e('生成回复失败: $e');
      _messages[assistantIndex] = _messages[assistantIndex].copyWith(
        isStreaming: false,
        error: '生成回复失败: $e',
      );
    }

    _isGenerating = false;
    notifyListeners();
  }

  /// 执行 Skill（根据 ID）
  Future<String?> _executeSkillById(String skillId, Map<String, dynamic> params) async {
    try {
      print('[DEBUG] ========== 开始执行 Skill ==========');
      print('[DEBUG] Skill ID: $skillId');
      print('[DEBUG] 参数: $params');
      
      String? result;
      
      switch (skillId) {
        case 'weather':
          print('[DEBUG] 执行天气 Skill');
          result = await _executeWeatherSkill(params);
          break;
        
        case 'time':
          print('[DEBUG] 执行时间 Skill');
          result = await _executeTimeSkill(params);
          break;
        
        case 'translate':
          print('[DEBUG] 执行翻译 Skill');
          result = await _executeTranslateSkill(params);
          break;
        
        case 'web_search':
          print('[DEBUG] 执行搜索 Skill');
          result = await _executeWebSearchSkill(params);
          break;
        
        case 'calculator':
          print('[DEBUG] 执行计算器 Skill');
          result = await _executeCalculatorSkill(params);
          break;
        
        case 'reminder':
          print('[DEBUG] 执行提醒 Skill');
          result = await _executeReminderSkill(params);
          break;
        
        case 'timer':
          print('[DEBUG] 执行倒计时 Skill');
          result = await _executeTimerSkill(params);
          break;
        
        case 'random':
          print('[DEBUG] 执行随机数 Skill');
          result = await _executeRandomSkill(params);
          break;
        
        case 'joke':
          print('[DEBUG] 执行笑话 Skill');
          result = await _executeJokeSkill(params);
          break;
        
        default:
          print('[DEBUG] ⚠️ 未知 Skill: $skillId');
          return '⚠️ 未知的 Skill: $skillId';
      }
      
      print('[DEBUG] Skill 执行成功');
      print('[DEBUG] 结果: $result');
      print('[DEBUG] ========== Skill 执行结束 ==========');
      
      return result;
    } catch (e, stackTrace) {
      print('[DEBUG] ❌ Skill 执行失败: $e');
      print('[DEBUG] 堆栈跟踪: $stackTrace');
      return '❌ Skill 执行失败: $e';
    }
  }

  /// 天气 Skill
  Future<String> _executeWeatherSkill(Map<String, dynamic> params) async {
    final location = params['location']?.toString();
    if (location == null || location.isEmpty) {
      return '请告诉我要查询哪个城市的天气';
    }

    print('[DEBUG] 查询天气: $location');
    
    try {
      // 方案 1：wttr.in
      print('[DEBUG] 尝试 wttr.in API...');
      final response = await http.Client().get(
        Uri.parse('https://wttr.in/${Uri.encodeComponent(location)}?format=3&lang=zh'),
      ).timeout(Duration(seconds: 10));

      print('[DEBUG] wttr.in 响应状态码: ${response.statusCode}');
      print('[DEBUG] wttr.in 响应内容: ${response.body}');

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        // 强制使用 UTF-8 解码，避免乱码
        final result = utf8.decode(response.bodyBytes).trim();
        print('[DEBUG] 天气结果: $result');
        return '🌤️ $result';
      }
      
      // 如果 wttr.in 失败，尝试备用方案
      print('[DEBUG] wttr.in 失败，尝试备用方案...');
      
      // 方案 2：使用简化的天气描述
      return '🌤️ 天气查询暂时不可用\n\n请稍后再试，或使用其他天气应用查询 $location 的天气。\n\n（错误码: ${response.statusCode}）';
      
    } catch (e) {
      print('[DEBUG] 天气查询出错: $e');
      return '🌤️ 天气查询失败\n\n网络连接出现问题，请检查网络后重试。\n\n错误: $e';
    }
  }

  /// 时间 Skill
  Future<String> _executeTimeSkill(Map<String, dynamic> params) async {
    final now = DateTime.now();
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];
    
    return '🕐 现在是 ${now.year}年${now.month}月${now.day}日 星期$weekday ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 翻译 Skill
  Future<String> _executeTranslateSkill(Map<String, dynamic> params) async {
    final text = params['text']?.toString();
    final targetLang = params['target_lang']?.toString() ?? 'en';
    
    if (text == null || text.isEmpty) {
      return '请告诉我要翻译的内容';
    }

    // 使用 LLM 进行翻译
    if (_llmProvider != null) {
      try {
        final messages = [
          ChatMessage.user('请将以下文本翻译成${_getLanguageName(targetLang)}：\n\n$text'),
        ];

        final stream = _llmProvider!.chatStream(messages);
        final buffer = StringBuffer();

        await for (final event in stream) {
          if (event.done || event.error != null) break;
          if (event.delta != null) buffer.write(event.delta);
        }

        return '🌐 翻译结果：\n${buffer.toString()}';
      } catch (e) {
        return '翻译失败: $e';
      }
    }

    return '翻译功能需要配置大模型';
  }

  /// 网页搜索 Skill
  Future<String> _executeWebSearchSkill(Map<String, dynamic> params) async {
    final query = params['query']?.toString();
    
    if (query == null || query.isEmpty) {
      return '请告诉我要搜索什么';
    }

    print('[DEBUG] 执行搜索: $query');

    // 如果没有配置 LLM，返回提示
    if (_llmProvider == null) {
      return '🔍 搜索功能需要配置大模型\n\n请先在"模型"标签页配置大模型。';
    }

    try {
      // 使用 LLM 直接回答（更可靠）
      final messages = [
        ChatMessage.system('你是一个知识渊博的助手。请回答用户的问题，提供准确、详细的信息。'),
        ChatMessage.user(query),
      ];

      final stream = _llmProvider!.chatStream(messages);
      final buffer = StringBuffer();

      await for (final event in stream) {
        if (event.done || event.error != null) break;
        if (event.delta != null) buffer.write(event.delta);
      }

      final result = buffer.toString().trim();
      
      if (result.isNotEmpty) {
        return '🔍 关于"$query"：\n\n$result';
      } else {
        return '抱歉，我没有找到相关信息。';
      }
    } catch (e) {
      print('[DEBUG] 搜索出错: $e');
      return '搜索失败: $e\n\n请检查网络连接或稍后重试。';
    }
  }

  /// 计算器 Skill
  Future<String> _executeCalculatorSkill(Map<String, dynamic> params) async {
    final expression = params['expression']?.toString();
    
    if (expression == null || expression.isEmpty) {
      return '请告诉我计算表达式';
    }

    try {
      // 简单的表达式计算（仅支持基本运算）
      // 注意：实际应用中应该使用更安全的表达式解析库
      final result = _evaluateExpression(expression);
      return '🔢 计算结果：$expression = $result';
    } catch (e) {
      return '计算失败: $e';
    }
  }

  /// 简单的表达式计算
  double _evaluateExpression(String expression) {
    // 移除空格
    final expr = expression.replaceAll(' ', '');
    
    // 仅支持基本的加减乘除
    if (expr.contains('+')) {
      final parts = expr.split('+');
      return double.parse(parts[0]) + double.parse(parts[1]);
    } else if (expr.contains('-') && expr.lastIndexOf('-') > 0) {
      final parts = expr.split('-');
      return double.parse(parts[0]) - double.parse(parts[1]);
    } else if (expr.contains('*')) {
      final parts = expr.split('*');
      return double.parse(parts[0]) * double.parse(parts[1]);
    } else if (expr.contains('/')) {
      final parts = expr.split('/');
      return double.parse(parts[0]) / double.parse(parts[1]);
    }
    
    return double.parse(expr);
  }

  /// 提醒 Skill
  Future<String> _executeReminderSkill(Map<String, dynamic> params) async {
    final time = params['time']?.toString();
    final content = params['content']?.toString();

    print('[DEBUG] 提醒参数 - 时间: $time, 内容: $content');

    if (time == null || time.isEmpty) {
      return '⚠️ 请提供提醒时间\n示例："提醒我1小时后开会"';
    }

    if (content == null || content.isEmpty) {
      return '⚠️ 请提供提醒内容\n示例："提醒我1小时后开会"';
    }

    // 解析时间（简单实现）
    final duration = _parseReminderTime(time);
    if (duration == null) {
      return '⚠️ 无法识别时间格式：$time\n支持格式：1小时后、30分钟后、10秒后';
    }

    // 设置定时器
    final timerId = 'reminder_${DateTime.now().millisecondsSinceEpoch}';
    Timer(duration, () {
      // 添加提醒消息到对话列表
      final reminderMsg = ConversationMessage(
        id: 'reminder_${_messageIndex++}',
        role: MessageRole.assistant,
        content: '⏰ **提醒时间到！**\n\n$content',
      );
      _messages.add(reminderMsg);
      notifyListeners();
      
      print('[Reminder] 提醒触发: $content');
    });

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    String timeStr;
    if (minutes > 0) {
      timeStr = seconds > 0 ? '$minutes 分 $seconds 秒' : '$minutes 分钟';
    } else {
      timeStr = '$seconds 秒';
    }

    return '✅ 已设置提醒\n⏰ $timeStr 后提醒您：$content';
  }

  /// 解析提醒时间
  Duration? _parseReminderTime(String timeStr) {
    final lower = timeStr.toLowerCase();

    // X小时后
    final hourMatch = RegExp(r'(\d+)\s*小时').firstMatch(lower);
    if (hourMatch != null) {
      final hours = int.parse(hourMatch.group(1)!);
      return Duration(hours: hours);
    }

    // X分钟后
    final minuteMatch = RegExp(r'(\d+)\s*分钟').firstMatch(lower);
    if (minuteMatch != null) {
      final minutes = int.parse(minuteMatch.group(1)!);
      return Duration(minutes: minutes);
    }

    // X秒后
    final secondMatch = RegExp(r'(\d+)\s*秒').firstMatch(lower);
    if (secondMatch != null) {
      final seconds = int.parse(secondMatch.group(1)!);
      return Duration(seconds: seconds);
    }

    return null;
  }

  /// 倒计时 Skill
  Future<String> _executeTimerSkill(Map<String, dynamic> params) async {
    final duration = params['duration']?.toString();

    print('[DEBUG] 倒计时参数 - 时长: $duration');

    if (duration == null || duration.isEmpty) {
      return '⚠️ 请提供倒计时时长\n示例："倒计时5分钟"';
    }

    // 解析时长
    final parsedDuration = _parseTimerDuration(duration);
    if (parsedDuration == null) {
      return '⚠️ 无法识别时长：$duration\n支持格式：5分钟、1小时、30秒';
    }

    // 启动倒计时
    final timerId = 'timer_${DateTime.now().millisecondsSinceEpoch}';
    Timer(parsedDuration, () {
      // TODO: 发送通知
      print('[Timer] 倒计时结束: $timerId');
    });

    final minutes = parsedDuration.inMinutes;
    final seconds = parsedDuration.inSeconds % 60;

    String timeStr;
    if (minutes > 0) {
      timeStr = seconds > 0 ? '$minutes 分 $seconds 秒' : '$minutes 分钟';
    } else {
      timeStr = '$seconds 秒';
    }

    return '⏱️ 已开始倒计时\n⏰ 时长：$timeStr\n📦 计时器ID：$timerId';
  }

  /// 解析倒计时时长
  Duration? _parseTimerDuration(String durationStr) {
    final lower = durationStr.toLowerCase();

    // X小时
    final hourMatch = RegExp(r'(\d+)\s*小时').firstMatch(lower);
    if (hourMatch != null) {
      final hours = int.parse(hourMatch.group(1)!);
      return Duration(hours: hours);
    }

    // X分钟
    final minuteMatch = RegExp(r'(\d+)\s*分钟').firstMatch(lower);
    if (minuteMatch != null) {
      final minutes = int.parse(minuteMatch.group(1)!);
      return Duration(minutes: minutes);
    }

    // X秒
    final secondMatch = RegExp(r'(\d+)\s*秒').firstMatch(lower);
    if (secondMatch != null) {
      final seconds = int.parse(secondMatch.group(1)!);
      return Duration(seconds: seconds);
    }

    return null;
  }

  /// 获取语言名称
  String _getLanguageName(String code) {
    const langMap = {
      'en': '英语',
      'ja': '日语',
      'ko': '韩语',
      'fr': '法语',
      'de': '德语',
      'es': '西班牙语',
      'ru': '俄语',
      'pt': '葡萄牙语',
      'it': '意大利语',
    };
    return langMap[code] ?? code;
  }

  /// 播放语音回复（TTS）
  void _speakResponse(String text) async {
    try {
      // 移除 emoji 和特殊字符，只保留文字
      final cleanText = text.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9\s\.,!?，。！？]'), '');

      if (cleanText.trim().isEmpty) return;

      // 播放语音
      await _ttsService.speak(cleanText);
    } catch (e) {
      _logger.e('语音播放失败: $e');
    }
  }

  /// 执行 Skill
  Future<String> executeSkill(String skillId, Map<String, dynamic> params) async {
    final skill = _skillManager.registry.get(skillId);
    if (skill == null) {
      throw Exception('Skill not found: $skillId');
    }
    return _skillManager.executeSkill(skill, params);
  }

  /// 保存对话历史
  Future<void> _saveConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _messages.map((m) {
      return {
        'id': m.id,
        'role': m.role.name,
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
      };
    }).toList();
    await prefs.setString('conversation_history', jsonEncode(history));
  }

  /// 清空对话历史
  Future<void> clearConversation() async {
    _messages.clear();
    _llmMessages.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('conversation_history');

    notifyListeners();
  }

  // ==================== 远程连接 ====================

  /// 连接远程 Gateway
  Future<bool> connectRemote() async {
    if (_capabilityConfig.l4RemoteUrl == null) {
      _error = '未配置远程 Gateway URL';
      notifyListeners();
      return false;
    }

    try {
      _remoteConnection = RemoteConnection(
        url: _capabilityConfig.l4RemoteUrl!,
        token: _capabilityConfig.l4RemoteToken,
      );

      final success = await _remoteConnection!.connect();
      if (!success) {
        _error = '连接远程 Gateway 失败';
        _remoteConnection = null;
      }

      notifyListeners();
      return success;
    } catch (e) {
      _error = '连接远程 Gateway 出错: $e';
      notifyListeners();
      return false;
    }
  }

  /// 断开远程连接
  void disconnectRemote() {
    _remoteConnection?.disconnect();
    _remoteConnection = null;
    notifyListeners();
  }

  // ==================== 任务管理 ====================

  /// 添加任务
  String addTask(String description) {
    final task = TaskInfo(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      description: description,
      status: TaskStatus.running,
      startTime: DateTime.now(),
    );

    _tasks.add(task);
    notifyListeners();

    // 启动定时器更新进度（示例）
    _startTaskProgress(task.id);

    return task.id;
  }

  /// 更新任务进度
  void updateTaskProgress(String taskId, double progress) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = TaskInfo(
        id: task.id,
        description: task.description,
        status: task.status,
        progress: progress,
        error: task.error,
        startTime: task.startTime,
        endTime: task.endTime,
      );
      notifyListeners();
    }
  }

  /// 完成任务
  void completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = TaskInfo(
        id: task.id,
        description: task.description,
        status: TaskStatus.completed,
        progress: 1.0,
        error: task.error,
        startTime: task.startTime,
        endTime: DateTime.now(),
      );
      _taskTimers[taskId]?.cancel();
      _taskTimers.remove(taskId);
      notifyListeners();

      // 3秒后移除已完成的任务
      Future.delayed(const Duration(seconds: 3), () {
        _tasks.removeWhere((t) => t.id == taskId && t.status == TaskStatus.completed);
        notifyListeners();
      });
    }
  }

  /// 任务失败
  void failTask(String taskId, String error) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = TaskInfo(
        id: task.id,
        description: task.description,
        status: TaskStatus.failed,
        progress: task.progress,
        error: error,
        startTime: task.startTime,
        endTime: DateTime.now(),
      );
      _taskTimers[taskId]?.cancel();
      _taskTimers.remove(taskId);
      notifyListeners();
    }
  }

  /// 启动任务进度更新（示例）
  void _startTaskProgress(String taskId) {
    var progress = 0.0;
    _taskTimers[taskId] = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      progress += 0.1;
      if (progress >= 1.0) {
        completeTask(taskId);
        timer.cancel();
      } else {
        updateTaskProgress(taskId, progress);
      }
    });
  }

  // ==================== 会话管理 ====================

  /// 刷新会话列表
  Future<void> refreshSessions() async {
    if (!isRemoteConnected) return;

    try {
      // 暂时先清空会话列表，等待 RemoteConnection 实现完成
      _sessions.clear();
      notifyListeners();
    } catch (e) {
      _logger.e('刷新会话列表失败: $e');
    }
  }

  /// 创建新会话
  Future<String?> createNewSession({String? name}) async {
    if (!isRemoteConnected) return null;

    try {
      // 暂时返回 null，等待 RemoteConnection 实现完成
      return null;
    } catch (e) {
      _logger.e('创建会话失败: $e');
      return null;
    }
  }

  /// 创建会话（别名）
  Future<bool> createSession({String? name}) async {
    final sessionId = await createNewSession(name: name);
    return sessionId != null;
  }

  // ==================== Gateway 管理 ====================

  /// 获取 Gateway 信息
  GatewayInfo? get gatewayInfo {
    return _remoteConnection?.gatewayInfo;
  }

  /// 刷新 Gateway 数据
  Future<void> refreshGatewayData() async {
    if (!isRemoteConnected) return;

    try {
      // 暂时不做任何操作，等待 RemoteConnection 实现完成
      notifyListeners();
    } catch (e) {
      _logger.e('刷新 Gateway 数据失败: $e');
    }
  }

  /// 获取远程任务列表
  List<Map<String, dynamic>> get remoteTasks {
    // 暂时返回空列表，等待 RemoteConnection 实现完成
    return [];
  }

  /// 取消远程任务
  Future<bool> cancelRemoteTask(String taskId) async {
    if (!isRemoteConnected) return false;

    try {
      // 暂时返回 false，等待 RemoteConnection 实现完成
      return false;
    } catch (e) {
      _logger.e('取消远程任务失败: $e');
      return false;
    }
  }

  /// 重启会话
  Future<bool> restartSession(String sessionId) async {
    if (!isRemoteConnected) return false;

    try {
      // 暂时返回 false，等待 RemoteConnection 实现完成
      return false;
    } catch (e) {
      _logger.e('重启会话失败: $e');
      return false;
    }
  }

  /// 发送 Gateway 命令
  Future<bool> sendGatewayCommand(String command) async {
    if (!isRemoteConnected) return false;

    try {
      // 暂时返回 false，等待 RemoteConnection 实现完成
      return false;
    } catch (e) {
      _logger.e('发送 Gateway 命令失败: $e');
      return false;
    }
  }

  // ==================== 更多 Skill 实现 ====================

  /// 随机数 Skill
  Future<String> _executeRandomSkill(Map<String, dynamic> params) async {
    final min = params['min'] as int? ?? 1;
    final max = params['max'] as int? ?? 100;
    
    final random = DateTime.now().millisecondsSinceEpoch % (max - min + 1) + min;
    return '🎲 随机数 ($min-$max): $random';
  }

  /// 笑话 Skill
  Future<String> _executeJokeSkill(Map<String, dynamic> params) async {
    final jokes = [
      '为什么程序员总是分不清万圣节和圣诞节？因为 Oct 31 == Dec 25',
      '有一种鸟叫做"程序员鸟"，它只会说两句话："在我的机器上能运行"和"这不是 bug，这是 feature"',
      '客户：这个程序很简单啊，应该很快就能做完吧？\n程序员：好的，那我先去喝杯咖啡。',
      '程序员最讨厌的四件事：写注释、写文档、别人不写注释、别人不写文档',
      '程序员的三大谎言：1. 这个功能很简单 2. 马上就好 3. 我以后会重构的',
      '为什么程序员喜欢暗色主题？因为 light 会 attract bugs！',
      '一个 SQL 语句走进酒吧，看到两张表，于是问道："我能 JOIN 你们吗？"',
      '程序员的浪漫：你是我的 private，我是你的 public，我们之间有一个 interface',
    ];
    
    final index = DateTime.now().millisecondsSinceEpoch % jokes.length;
    return '😄 ${jokes[index]}';
  }
}

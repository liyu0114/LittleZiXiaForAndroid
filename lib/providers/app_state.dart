// 应用状态管理
//
// 管理 LLM 配置、能力层、对话历史、Skills、远程连接、话题

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../services/llm/llm_base.dart';
import '../services/llm/llm_factory.dart';
import '../services/capabilities/capability_manager.dart';
import '../services/skills/skill_system.dart';
import '../services/skills/skill_lifecycle.dart' hide LLMProvider;  // 避免与 llm_base.dart 冲突
import '../services/skills/intent_recognizer.dart';
import '../services/skills/skill_summarizer.dart';
import '../services/skills/skill_manager_new.dart';
import '../services/agent/agent_orchestrator.dart';
import '../services/remote/remote_connection.dart';
import '../services/qrcode/qrcode_service.dart';
import '../services/voice/tts_service.dart';
import '../services/file/file_picker_service.dart';
import '../services/conversation/topic_manager.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sensors/sensor_service.dart';
import '../services/web/web_search_service.dart';
import '../services/web/web_fetch_service.dart';
import '../services/memory/memory_service.dart';
import '../services/vision/image_analysis_service.dart';
import '../services/context/context_manager.dart';
import '../widgets/task_list.dart';
import '../services/task_executor.dart';  // 任务执行引擎

/// 对话消息（UI 层使用）
class ConversationMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? error;
  
  // 新增：多媒体支持
  final String? imagePath;     // 图片路径
  final String? videoPath;     // 视频路径
  final String? filePath;      // 文件路径
  final String? fileName;      // 文件名
  final int? fileSize;         // 文件大小

  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.error,
    this.imagePath,
    this.videoPath,
    this.filePath,
    this.fileName,
    this.fileSize,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 是否有图片
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  
  /// 是否有视频
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;
  
  /// 是否有文件
  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  ConversationMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? error,
    String? imagePath,
    String? videoPath,
    String? filePath,
    String? fileName,
    int? fileSize,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
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
  late EnhancedSkillManager _enhancedSkillManager;
  SkillSummarizer? _skillSummarizer;
  late SkillLifecycleManager _lifecycleManager;  // 新增

  // Agent 系统
  AgentOrchestrator? _agentOrchestrator;

  // 语音合成（TTS）
  late TTSService _ttsService;

  // 传感器服务
  late SensorService _sensorService;

  // 网页搜索服务
  late WebSearchService _webSearchService;

  // 焏页获取服务
  late WebFetchService _webFetchService;

  // Memory 服务
  late MemoryService _memoryService;

  // 上下文管理
  late ContextManager _contextManager;

  // 图像分析服务
  ImageAnalysisService? _imageAnalysisService;

  // 自定义 Skills
  List<CustomSkill> _customSkills = [];
  List<CustomSkill> get customSkills => _customSkills;

  // 远程连接
  RemoteConnection? _remoteConnection;

  // 二维码服务
  QRCodeService? _qrcodeService;

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
  EnhancedSkillManager get enhancedSkillManager => _enhancedSkillManager;
  AgentOrchestrator? get agentOrchestrator => _agentOrchestrator;
  TTSService get ttsService => _ttsService;
  SensorService get sensorService => _sensorService;
  MemoryService get memoryService => _memoryService;
  RemoteConnection? get remoteConnection => _remoteConnection;
  QRCodeService? get qrcodeService => _qrcodeService;
  bool get isRemoteConnected => _remoteConnection?.isConnected ?? false;

  /// 设置远程连接
  void setRemoteConnection(RemoteConnection? connection) {
    _remoteConnection = connection;
    notifyListeners();
  }

  CapabilityConfig get capabilityConfig => _capabilityConfig;
  CapabilityManager get capabilityManager => _capabilityManager;
  List<TaskInfo> get tasks => List.unmodifiable(_tasks);
  List<TaskInfo> get activeTasks => _tasks.where((t) => t.status == TaskStatus.running).toList();
  List<SessionInfo> get sessions => List.unmodifiable(_sessions);
  SkillLifecycleManager get lifecycleManager => _lifecycleManager;  // 新增
  
  /// 从对话生成 Skill（老板要求的功能）
  Future<SkillLifecycleItem?> generateSkillFromConversation(
    String conversationContent,
    String skillName,
  ) async {
    if (_llmProvider == null) {
      _error = '请先配置大模型';
      notifyListeners();
      return null;
    }

    try {
      // 创建简化的聊天回调函数
      Future<String> chatCallback(String prompt) async {
        final messages = [ChatMessage(role: MessageRole.user, content: prompt)];
        final response = await _llmProvider!.chat(messages);
        return response.content;
      }
      
      final item = await _lifecycleManager.generateFromConversation(
        conversationContent,
        skillName,
        chatCallback,
      );
      
      if (item != null) {
        notifyListeners();
      }
      
      return item;
    } catch (e) {
      _error = '生成 Skill 失败: $e';
      notifyListeners();
      return null;
    }
  }

  AppState() {
    _capabilityManager = CapabilityManager(config: _capabilityConfig);
    _skillManager = SkillManager();
    _enhancedSkillManager = EnhancedSkillManager();
    _topicManager = TopicManager();

    // 初始化 TTS
    _ttsService = TTSService();

    // 初始化传感器服务
    _sensorService = SensorService();

    // 初始化网页服务
    _webSearchService = WebSearchService();
    _webFetchService = WebFetchService();

    // 初始化 Memory 服务
    _memoryService = MemoryService();

    // 初始化上下文管理
    _contextManager = ContextManager();

    // 初始化二维码服务
    _qrcodeService = QRCodeService();

    // 异步加载 Skills 和 话题
    _initializeSkills();
    _initializeTopics();

    _loadConfig();
  }

  /// 初始化 Skills
  Future<void> _initializeSkills() async {
    await _skillManager.initialize();
    await _enhancedSkillManager.initialize();
    
    // 初始化 Skill 生命周期管理器
    _lifecycleManager = SkillLifecycleManager(_skillManager.registry);
    await _lifecycleManager.initialize();
    debugPrint('[AppState] Skill 生命周期管理器初始化完成');
    
    debugPrint('[AppState] Skills 初始化完成，skillRegistry.length = ${_skillManager.registry.length}');
    
    // 初始化 Agent 系统
    if (_llmProvider != null) {
      _agentOrchestrator = AgentOrchestrator();
      _agentOrchestrator!.initialize(
        llmProvider: _llmProvider!,
        memoryService: _memoryService,
        skillManager: _skillManager,
      );
      debugPrint('[AppState] Agent 系统初始化完成');
    }
    
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
    
    // 自动连接默认 Gateway（Windows龙虾）
    await _autoConnectDefaultGateway();
  }
  
  /// 自动连接默认 Gateway
  Future<void> _autoConnectDefaultGateway() async {
    // 如果已经有连接，跳过
    if (_remoteConnection != null && _remoteConnection!.isConnected) {
      return;
    }
    
    // 默认 Gateway 配置（Windows龙虾）
    const defaultUrl = 'http://100.80.206.8:18789';
    const defaultToken = '6374a3974149286117d8df733c6f20dfd7d8bed73aa9de7c';
    
    try {
      _logger.i('尝试自动连接默认 Gateway: $defaultUrl');
      final connection = RemoteConnection(url: defaultUrl, token: defaultToken);
      final success = await connection.connect();
      
      if (success) {
        _remoteConnection = connection;
        _logger.i('自动连接默认 Gateway 成功');
        notifyListeners();
      } else {
        _logger.w('自动连接默认 Gateway 失败: ${connection.error}');
      }
    } catch (e) {
      _logger.w('自动连接默认 Gateway 出错: $e');
    }
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

    // 添加用户消息（包含多媒体信息）
    final userMsg = ConversationMessage(
      id: 'user_${_messageIndex++}',
      role: MessageRole.user,
      content: content,
      imagePath: imagePath,
      videoPath: videoPath,
      filePath: fileResult?.path,
      fileName: fileResult?.name,
      fileSize: fileResult?.size,
    );
    _messages.add(userMsg);
    
    // 同时添加到话题管理器
    if (_topicManager.currentTopic != null) {
      _topicManager.currentTopic!.addMessage(ChatMessage.user(content));
    }
    
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
      
      // 同时添加到话题管理器
      if (_topicManager.currentTopic != null) {
        _topicManager.currentTopic!.addMessage(ChatMessage.assistant(buffer.toString()));
        _topicManager.save(); // 保存话题
      }
      
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
      
      // 从 SkillManager 获取技能（全部从外部加载）
      final skill = _skillManager.registry.get(skillId);
      if (skill != null) {
        print('[DEBUG] ✓ 从 SkillManager 找到技能: ${skill.metadata.name}');
        final result = await _skillManager.executeSkill(skill, params);
        print('[DEBUG] Skill 执行结果: $result');
        return result;
      }
      
      print('[DEBUG] 没有找到可执行的 Skill: $skillId');
      return '⚠️ Skill "$skillId" 未安装或不可用';
    } catch (e) {
      print('[DEBUG] Skill 执行失败: $e');
      return '❌ Skill 执行失败: $e';
    }
  }

  /// 天气 Skill
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
  // ==================== 权限管理 ====================

  /// 检查是否拥有所有必要权限
  Future<bool> hasAllPermissions() async {
    try {
      final permissions = [
        Permission.location,
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.notification,
      ];

      for (final permission in permissions) {
        final status = await permission.status;
        if (!status.isGranted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('[DEBUG] 检查权限失败: $e');
      return false;
    }
  }

  /// 请求所有必要权限
  Future<Map<Permission, PermissionStatus>> requestPermissions() async {
    final results = <Permission, PermissionStatus>{};

    try {
      final permissions = [
        Permission.location,
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.notification,
      ];

      for (final permission in permissions) {
        final status = await permission.request();
        results[permission] = status;
        print('[DEBUG] 权限 ${permission.toString()}: $status');
      }
    } catch (e) {
      print('[DEBUG] 请求权限失败: $e');
    }

    return results;
  }

  /// 打开应用设置页面
  Future<void> openPermissionSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      print('[DEBUG] 打开设置失败: $e');
    }
  }
}

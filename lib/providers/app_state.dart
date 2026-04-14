// 应用状态管理
//
// 管理 LLM 配置、能力层、对话历史、Skills、远程连接、话题

import 'dart:async';
import 'dart:convert';
import 'dart:io';  // 用于读取图片文件
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
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
import '../services/agent/task_decomposer.dart';
import '../services/remote/remote_connection.dart';
import '../services/qrcode/qrcode_service.dart';
import '../services/voice/tts_service.dart';
import '../services/file/file_picker_service.dart';
import '../services/conversation/topic_manager.dart';
import '../services/sensors/sensor_service.dart';
import '../services/web/web_search_service.dart';
import '../services/web/web_fetch_service.dart';
import '../services/memory/memory_service.dart';
import '../services/vision/image_analysis_service.dart';
import '../services/context/context_manager.dart';
import '../services/llm_logger_service.dart';  // LLM 日志服务
import '../services/agent/agent_loop_v2.dart';
import '../services/agent/agent_tools.dart';
import '../services/context/smart_context_service.dart';
import '../services/sandbox/code_sandbox_service.dart';
import '../services/sandbox/code_agent_tools.dart';
import '../services/web/web_agent_tools.dart';
import '../widgets/task_list.dart';

/// Agent 执行步骤（用于 UI 展示进度）
class AgentStep {
  final String id;
  final String description;
  String status; // pending, running, completed, failed, retrying
  String? result;
  String? error;
  int retryCount;

  AgentStep({
    required this.id,
    required this.description,
    this.status = 'pending',
    this.result,
    this.error,
    this.retryCount = 0,
  });

  String get icon {
    switch (status) {
      case 'pending': return '⏳';
      case 'running': return '🔄';
      case 'completed': return '✅';
      case 'failed': return '❌';
      case 'retrying': return '🔁';
      default: return '❓';
    }
  }

  @override
  String toString() => '$icon $description${status == 'completed' && result != null ? '\n   → ${result!.length > 80 ? '${result!.substring(0, 80)}...' : result!}' : ''}';
}

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

  // Agent 步骤进度
  final List<AgentStep> agentSteps;

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
    List<AgentStep>? agentSteps,
  }) : timestamp = timestamp ?? DateTime.now(),
       agentSteps = agentSteps ?? [];

  /// 是否有图片
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  
  /// 是否有视频
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;
  
  /// 是否有文件
  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  
  /// 是否是 Agent 消息
  bool get isAgentMessage => agentSteps.isNotEmpty;

  /// Agent 进度摘要
  String get agentProgressText {
    if (agentSteps.isEmpty) return '';
    final completed = agentSteps.where((s) => s.status == 'completed').length;
    return '($completed/${agentSteps.length})';
  }

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
    List<AgentStep>? agentSteps,
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
      agentSteps: agentSteps ?? this.agentSteps,
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

  // 智能上下文服务（对话压缩 + 跨话题记忆）
  final SmartContextService _smartContext = SmartContextService();
  SmartContextService get smartContext => _smartContext;

  // 图像分析服务
  ImageAnalysisService? _imageAnalysisService;

  // 自定义 Skills
  List<CustomSkill> _customSkills = [];
  List<CustomSkill> get customSkills => _customSkills;

  // 远程连接
  RemoteConnection? _remoteConnection;

  // Agent Loop V2
  final AgentLoopServiceV2 _agentLoopV2 = AgentLoopServiceV2();

  // 代码沙盒
  final CodeSandboxService _codeSandbox = CodeSandboxService();

  // 二维码服务
  QRCodeService? _qrcodeService;

  // 能力层
  CapabilityConfig _capabilityConfig = CapabilityConfig();
  late CapabilityManager _capabilityManager;

  // 任务管理
  final List<TaskInfo> _tasks = [];
  final Map<String, Timer> _taskTimers = {};

  // 会话管理
  final List<Map<String, dynamic>> _sessions = [];

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
  AgentLoopServiceV2 get agentLoopV2 => _agentLoopV2;
  CodeSandboxService get codeSandbox => _codeSandbox;

  // 待发送消息（从其他页面跳转来）
  String? _pendingMessage;
  String? get pendingMessage => _pendingMessage;
  void setPendingMessage(String message) {
    _pendingMessage = message;
    notifyListeners();
  }
  void clearPendingMessage() {
    _pendingMessage = null;
  }

  /// 设置远程连接
  void setRemoteConnection(RemoteConnection? connection) {
    _remoteConnection = connection;
    notifyListeners();
  }

  CapabilityConfig get capabilityConfig => _capabilityConfig;
  CapabilityManager get capabilityManager => _capabilityManager;
  List<TaskInfo> get tasks => List.unmodifiable(_tasks);
  List<TaskInfo> get activeTasks => _tasks.where((t) => t.status == TaskStatus.running).toList();
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);
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

    // 初始化智能上下文服务
    _smartContext.loadSummaries();

    // 初始化二维码服务
    _qrcodeService = QRCodeService();

    // 异步加载 Skills 和 话题
    _initializeSkills();
    _initializeTopics();
    _codeSandbox.loadFromDisk();

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

    // 同步更新 Agent Loop V2
    _agentLoopV2.updateProvider(_llmProvider!);
    _smartContext.initialize(_llmProvider!);
    _registerAgentTools();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_config', jsonEncode(config.toJson()));

    notifyListeners();
  }

  /// 注册 Agent 工具
  void _registerAgentTools() {
    if (_llmProvider == null) return;

    // 初始化 Agent Loop V2
    _agentLoopV2.initialize(
      llmProvider: _llmProvider!,
      memoryService: _memoryService,
    );

    // 注册基础工具
    registerBaseTools(_agentLoopV2);

    // 注册记忆工具
    registerMemoryTools(_agentLoopV2, _memoryService);

    // 注册 Skill 工具
    registerSkillTools(_agentLoopV2, _skillManager);

    // 注册代码沙盒工具
    registerCodeSandboxTools(_agentLoopV2, _codeSandbox);

    // 注册 Web 工具（搜索+获取）
    registerWebTools(_agentLoopV2, _webSearchService, _webFetchService);

    // 设置工具调用回调（UI 实时展示）
    _agentLoopV2.onToolCall = _onAgentToolCall;
    _agentLoopV2.onToolResult = _onAgentToolResult;

    debugPrint('[AppState] Agent Loop V2 工具注册完成: ${_agentLoopV2.registeredTools.length} 个');
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
    List<String>? imageBase64List;
    
    // 检测是否为视觉模型且有图片
    final isVisionModel = llmConfig?.isVisionModel ?? false;
    if (imagePath != null && isVisionModel) {
      try {
        // 读取图片文件并转换为 base64
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64 = base64Encode(bytes);
          imageBase64List = ['data:image/jpeg;base64,$base64'];
          llmContent = content; // 视觉模型不需要文本描述图片
          debugPrint('[AppState] 图片已转换为 base64，长度: ${base64.length}');
        } else {
          llmContent = '[用户发送了一张图像，但文件不存在]\n$content';
        }
      } catch (e) {
        debugPrint('[AppState] 读取图片失败: $e');
        llmContent = '[用户发送了一张图像，但读取失败]\n$content';
      }
    } else if (imagePath != null) {
      llmContent = '[用户发送了一张图像]\n$content';
      debugPrint('[AppState] 当前模型不支持图片: ${llmConfig?.model}');
    }
    if (videoPath != null) {
      llmContent = '[用户发送了一段视频（15秒以内）]\n$content';
      // TODO: 支持 Video LLM
    }
    if (fileResult != null) {
      llmContent = '[用户发送了一个文件：${fileResult.name}]\n$content';
      // TODO: 支持 Document LLM
    }
    
    // 添加消息到 LLM 历史
    if (imageBase64List != null && imageBase64List.isNotEmpty) {
      // 多模态消息（带图片）
      // 直接传递 URL 格式的 Map
      final imageMaps = imageBase64List.map((b64) => <String, dynamic>{'url': b64}).toList();
      _llmMessages.add(ChatMessage.multimodal(
        text: llmContent,
        images: imageMaps,
      ));
      debugPrint('[AppState] 已添加多模态消息: ${imageMaps.length} 张图片');
    } else {
      // 普通文本消息
      _llmMessages.add(ChatMessage.user(llmContent));
    }

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

    // 如果 Skill 有响应且不是失败信息，直接返回
    if (skillResponse != null && !skillResponse.startsWith('⚠️') && !skillResponse.startsWith('❌')) {
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

    // Skill 不可用或失败 → 降级到 Agent Loop 或 LLM
    // Agent Loop 可以调用 web_search 等工具自主解决问题
    if (skillResponse != null && _agentLoopV2.registeredTools.isNotEmpty) {
      debugPrint('[AppState] Skill 不可用，降级到 Agent Loop 自主解决');
      // 构建 Agent 任务，让 Agent 自己想办法
      final agentTask = '用户问：$content\n注意：请用可用的工具来回答用户的问题。';
      // 强制单步模式，不走 TaskDecomposer（避免简单问题被过度分解）
      _isSingleStepTask = true;
      await _executeWithAgentLoop(agentTask);
      return;
    }

    // 否则，检查是否需要 Agent Loop（多步任务）
    if (_shouldUseAgentLoop(content)) {
      print('[DEBUG] 检测到多步任务，启用 Agent Loop V2');
      await _executeWithAgentLoop(content);
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
      // 智能上下文窗口管理：自动裁剪超限的消息
      final contextMessages = _smartContext.fitContextWindow(_llmMessages);
      final stream = _llmProvider!.chatStream(contextMessages);
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
        
        // 检查是否需要压缩对话历史
        await _tryCompressHistory();
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

  /// 判断是否应该使用 Agent Loop
  /// 多步任务特征：包含"然后"、"之后"、"并且"等连接词，或者多个动词
  /// 判断是否需要 Agent 模式（LLM 智能判断 + 正则快速路径）
  bool _shouldUseAgentLoop(String content) {
    if (_agentLoopV2.registeredTools.isEmpty) return false;
    if (_llmProvider == null) return false;

    // 快速路径：明确的多步任务关键词（需要 TaskDecomposer 分解）
    final multiStepPatterns = [
      RegExp(r'然后.+(?:再|还|也|和|比较|翻译|搜索|查|发)'),
      RegExp(r'之后.+(?:再|还|也)'),
      RegExp(r'先.+(?:然后|再|接着)'),
      RegExp(r'帮.+然后.+'),
      RegExp(r'查.+(?:然后|再|并).+(?:翻译|对比|总结|分析|发给)'),
      RegExp(r'搜索.+(?:然后|再|并).+(?:翻译|对比|总结|分析)'),
      RegExp(r'请.+(?:然后|再|并|和|以及)'),
      RegExp(r'分析.+(?:数据|报告|结果|对比|趋势)'),
    ];

    for (final pattern in multiStepPatterns) {
      if (pattern.hasMatch(content)) {
        debugPrint('[AppState] Agent Loop（多步）触发: "$content" 匹配 ${pattern.pattern}');
        return true;
      }
    }

    // 单步任务：直接走 Agent Loop（不经过 TaskDecomposer）
    // 这些任务只需要一个工具调用，不需要分解
    final singleStepPatterns = [
      RegExp(r'帮(?:我|忙)?.*(?:做|写|创建|开发|生成).*(?:程序|应用|app|计算器|游戏|工具|网页|页面|网站)'),
      RegExp(r'帮(?:我|忙)?.*(?:查|搜索|找).*(?:天气|新闻|资料|信息)'),
      RegExp(r'帮(?:我|忙)?.*(?:翻译|改|修改|更新|优化).*(?:代码|程序|项目)'),
      RegExp(r'写(?:一(?:个|份|段))?.*(?:代码|程序|HTML|CSS|JS|JavaScript)'),
      RegExp(r'创建(?:一(?:个|份))?.*(?:项目|应用|程序)'),
      RegExp(r'开发(?:一(?:个|份))?.*(?:程序|应用|小工具)'),
    ];

    for (final pattern in singleStepPatterns) {
      if (pattern.hasMatch(content)) {
        debugPrint('[AppState] Agent Loop（单步）触发: "$content" 匹配 ${pattern.pattern}');
        // 标记为单步任务，跳过 TaskDecomposer
        _isSingleStepTask = true;
        return true;
      }
    }

    return false;
  }

  /// 是否是单步任务（不需要 TaskDecomposer 分解）
  bool _isSingleStepTask = false;

  /// 使用 Agent Loop 执行多步任务（带任务分解 + 失败重试 + 实时进度）
  Future<void> _executeWithAgentLoop(String content) async {
    // 确保工具已注册
    if (_agentLoopV2.registeredTools.isEmpty) {
      _registerAgentTools();
    }

    // 添加 Agent 消息占位
    final agentMsg = ConversationMessage(
      id: 'assistant_${_messageIndex++}',
      role: MessageRole.assistant,
      content: '🤔 正在分析任务...',
      isStreaming: true,
      agentSteps: [],
    );
    _messages.add(agentMsg);
    _isGenerating = true;
    notifyListeners();

    final msgIndex = _messages.length - 1;

    try {
      // ===== 单步任务：直接执行，不走 TaskDecomposer =====
      if (_isSingleStepTask) {
        _isSingleStepTask = false;
        debugPrint('[AppState] 单步任务，直接走 Agent Loop');
        _updateAgentMessage(msgIndex, '⚡ 正在执行...', steps: [
          AgentStep(id: 'direct', description: '执行任务', status: 'running'),
        ]);

        final result = await _agentLoopV2.execute(content);
        
        _updateStepStatus(_messages[msgIndex].agentSteps, 'direct', 'completed',
          result: result.success ? result.content : result.error);
        _finishAgentMessage(msgIndex, result);
        return;
      }

      // ===== 多步任务：先分解再执行 =====
      _updateAgentMessage(msgIndex, '🧩 正在分解任务...', steps: [
        AgentStep(id: 'decompose', description: '分析并分解任务', status: 'running'),
      ]);

      final taskDecomposer = TaskDecomposer(llmProvider: _llmProvider!);
      final plan = await taskDecomposer.decompose(content);

      if (plan == null || plan.subtasks.isEmpty) {
        // 分解失败，回退到直接 Agent Loop
        debugPrint('[AppState] 任务分解失败，回退到直接执行');
        _updateAgentMessage(msgIndex, '🔄 任务分解失败，直接执行...', steps: [
          AgentStep(id: 'decompose', description: '分析并分解任务', status: 'failed', error: '无法分解'),
          AgentStep(id: 'direct', description: '直接执行任务', status: 'running'),
        ]);

        final result = await _agentLoopV2.execute(content);
        _finishAgentMessage(msgIndex, result);
        return;
      }

      // ===== 第2步：展示分解计划 =====
      final steps = plan.subtasks.map((s) => AgentStep(
        id: s.id,
        description: s.description,
      )).toList();

      debugPrint('[AppState] 任务分解完成: ${plan.subtasks.length} 个子任务');
      for (final s in plan.subtasks) {
        debugPrint('[AppState]   - ${s.id}: ${s.description} (依赖: ${s.dependencies})');
      }

      _updateAgentMessage(msgIndex, '📋 任务已分解为 ${steps.length} 个步骤，开始执行...', steps: [
        AgentStep(id: 'decompose', description: '分析并分解任务', status: 'completed',
          result: '分解为 ${steps.length} 个子任务'),
        ...steps,
      ]);

      // ===== 第3步：逐个执行子任务 =====
      final currentSteps = <AgentStep>[
        AgentStep(id: 'decompose', description: '分析并分解任务', status: 'completed',
          result: '分解为 ${steps.length} 个子任务'),
        ...steps,
      ];

      int maxRetries = 2; // 每个子任务最多重试2次

      while (!plan.isCompleted) {
        final nextTask = plan.getNextExecutable();
        if (nextTask == null) {
          // 检查是否有失败的子任务可以重试
          final failedTask = plan.subtasks.firstWhere(
            (s) => s.status == 'failed',
            orElse: () => SubTask(id: '', description: ''),
          );
          if (failedTask.id.isEmpty) break; // 没有可执行的了

          // 尝试重试失败任务（换思路）
          if (failedTask.result != null && !failedTask.result!.contains('已重试')) {
            _updateStepStatus(currentSteps, failedTask.id, 'retrying');
            _updateAgentMessage(msgIndex, '🔁 重试: ${failedTask.description}（换一种方式）', steps: currentSteps);

            failedTask.status = 'pending'; // 重置为待执行
            failedTask.result = '已重试';  // 标记已重试过
            continue;
          }
          break;
        }

        // 标记当前步骤为运行中
        _updateStepStatus(currentSteps, nextTask.id, 'running');
        _updateAgentMessage(msgIndex, '⚡ 执行: ${nextTask.description}', steps: currentSteps);

        // 执行子任务
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            final result = await _agentLoopV2.execute(nextTask.description);

            if (result.success) {
              plan.markCompleted(nextTask.id, result.content);
              _updateStepStatus(currentSteps, nextTask.id, 'completed', result: result.content);
              break;
            } else {
              // 失败
              if (attempt < maxRetries) {
                debugPrint('[AppState] 子任务 ${nextTask.id} 失败 (${attempt+1}/${maxRetries+1})，重试...');
                _updateStepStatus(currentSteps, nextTask.id, 'retrying', error: result.error);
                _updateAgentMessage(msgIndex,
                  '🔁 子任务失败，重试 (${attempt+1}/${maxRetries}): ${nextTask.description}',
                  steps: currentSteps);

                // 换思路：在描述中加上"换一种方式"
                await Future.delayed(Duration(seconds: 1));
                continue;
              } else {
                plan.markFailed(nextTask.id, result.error ?? '执行失败');
                _updateStepStatus(currentSteps, nextTask.id, 'failed', error: result.error);
              }
            }
          } catch (e) {
            if (attempt < maxRetries) {
              _updateStepStatus(currentSteps, nextTask.id, 'retrying', error: e.toString());
              await Future.delayed(Duration(seconds: 1));
              continue;
            } else {
              plan.markFailed(nextTask.id, e.toString());
              _updateStepStatus(currentSteps, nextTask.id, 'failed', error: e.toString());
            }
          }
        }

        // 更新进度显示
        final completedCount = currentSteps.where((s) => s.status == 'completed').length;
        final totalSteps = currentSteps.length;
        _updateAgentMessage(msgIndex,
          '📊 进度: $completedCount/$totalSteps 步骤完成',
          steps: currentSteps);
      }

      // ===== 第4步：汇总结果 =====
      final completedSteps = currentSteps.where((s) => s.status == 'completed').toList();
      final failedSteps = currentSteps.where((s) => s.status == 'failed').toList();

      final resultBuffer = StringBuffer();

      if (completedSteps.isNotEmpty) {
        // 用 LLM 汇总所有子任务结果
        final summaryPrompt = StringBuffer();
        summaryPrompt.writeln('原始任务: $content');
        summaryPrompt.writeln('');
        summaryPrompt.writeln('以下是各个子任务的执行结果，请汇总成一段完整的回复：');
        summaryPrompt.writeln('');
        for (final planTask in plan.subtasks) {
          if (planTask.result != null) {
            final truncated = planTask.result!.length > 500
                ? '${planTask.result!.substring(0, 500)}...'
                : planTask.result!;
            summaryPrompt.writeln('【${planTask.status == 'completed' ? '✅' : '❌'} ${planTask.description}】');
            summaryPrompt.writeln(truncated);
            summaryPrompt.writeln('');
          }
        }

        try {
          final summaryMessages = [ChatMessage.user(summaryPrompt.toString())];
          final summaryResponse = await _llmProvider!.chat(summaryMessages);
          resultBuffer.write(summaryResponse.content ?? '任务已完成');
        } catch (e) {
          // LLM 汇总失败，直接拼接
          resultBuffer.writeln('任务执行完成！');
          for (final planTask in plan.subtasks) {
            if (planTask.result != null) {
              resultBuffer.writeln('- ${planTask.description}: ${planTask.result!.length > 100 ? '${planTask.result!.substring(0, 100)}...' : planTask.result}');
            }
          }
        }
      } else {
        resultBuffer.write('❌ 任务执行失败：所有子任务均未成功完成');
      }

      // 更新最终消息
      _messages[msgIndex] = _messages[msgIndex].copyWith(
        content: resultBuffer.toString(),
        isStreaming: false,
        error: failedSteps.isNotEmpty ? '${failedSteps.length} 个步骤失败' : null,
        agentSteps: currentSteps,
      );

      _llmMessages.add(ChatMessage.assistant(resultBuffer.toString()));
      _speakResponse(resultBuffer.toString());
      _isGenerating = false;
      notifyListeners();

    } catch (e) {
      _messages[msgIndex] = _messages[msgIndex].copyWith(
        content: '❌ Agent 执行出错: $e',
        isStreaming: false,
        error: e.toString(),
      );
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 更新 Agent 消息的步骤进度
  void _updateAgentMessage(int index, String content, {required List<AgentStep> steps}) {
    if (index < 0 || index >= _messages.length) return;
    _messages[index] = _messages[index].copyWith(
      content: content,
      agentSteps: steps,
    );
    notifyListeners();
  }

  /// 更新某个步骤的状态
  void _updateStepStatus(List<AgentStep> steps, String stepId, String status, {String? result, String? error}) {
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].id == stepId) {
        steps[i] = AgentStep(
          id: steps[i].id,
          description: steps[i].description,
          status: status,
          result: result ?? steps[i].result,
          error: error ?? steps[i].error,
          retryCount: status == 'retrying' ? steps[i].retryCount + 1 : steps[i].retryCount,
        );
        break;
      }
    }
  }

  /// Agent 工具调用回调 - 实时更新 UI
  void _onAgentToolCall(String toolName, Map<String, dynamic> args) {
    if (_messages.isEmpty) return;
    final lastIdx = _messages.length - 1;
    if (!_messages[lastIdx].isStreaming) return;

    // 获取工具的友好名称
    final displayName = _getToolDisplayName(toolName, args);
    final currentSteps = _messages[lastIdx].agentSteps.toList();

    // 添加或更新工具调用步骤
    final existingIdx = currentSteps.indexWhere((s) => s.id == 'tool_$toolName');
    if (existingIdx >= 0) {
      currentSteps[existingIdx] = AgentStep(
        id: 'tool_$toolName',
        description: displayName,
        status: 'running',
      );
    } else {
      currentSteps.add(AgentStep(
        id: 'tool_$toolName',
        description: displayName,
        status: 'running',
      ));
    }

    _updateAgentMessage(lastIdx, '🔧 调用: $displayName', steps: currentSteps);
  }

  /// Agent 工具结果回调
  void _onAgentToolResult(String toolName, bool success, String? result) {
    if (_messages.isEmpty) return;
    final lastIdx = _messages.length - 1;
    if (!_messages[lastIdx].isStreaming) return;

    final currentSteps = _messages[lastIdx].agentSteps.toList();
    final existingIdx = currentSteps.indexWhere((s) => s.id == 'tool_$toolName');
    if (existingIdx >= 0) {
      currentSteps[existingIdx] = AgentStep(
        id: 'tool_$toolName',
        description: currentSteps[existingIdx].description,
        status: success ? 'completed' : 'failed',
        result: result != null && result.length > 80 ? '${result.substring(0, 80)}...' : result,
        error: success ? null : result,
      );
      _updateAgentMessage(lastIdx, _messages[lastIdx].content, steps: currentSteps);
    }
  }

  /// 获取工具调用的友好名称
  String _getToolDisplayName(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'web_search':
        return '搜索: ${args['query'] ?? ''}';
      case 'web_fetch':
        return '获取网页: ${args['url'] ?? ''}';
      case 'calculator':
        return '计算: ${args['expression'] ?? ''}';
      case 'get_current_time':
        return '获取当前时间';
      case 'memory_save':
        return '保存记忆';
      case 'memory_search':
        return '搜索记忆';
      case 'create_code_project':
        return '创建项目: ${args['name'] ?? ''}';
      default:
        if (toolName.startsWith('skill_')) {
          return '技能: ${toolName.replaceFirst('skill_', '')}';
        }
        return '调用: $toolName';
    }
  }

  /// 完成 Agent 消息（直接执行模式）
  void _finishAgentMessage(int index, AgentResult result) {
    if (index < 0 || index >= _messages.length) return;
    _messages[index] = _messages[index].copyWith(
      content: result.success
          ? result.content
          : '❌ 任务执行失败: ${result.error ?? "未知错误"}',
      isStreaming: false,
      error: result.success ? null : result.error,
    );

    if (result.success) {
      _llmMessages.add(ChatMessage.assistant(result.content));
      _speakResponse(result.content);
    }

    _isGenerating = false;
    notifyListeners();
  }

  /// 检查并压缩对话历史（异步，不阻塞 UI）
  Future<void> _tryCompressHistory() async {
    try {
      if (!_smartContext.shouldCompress(_llmMessages)) return;
      if (_topicManager.currentTopic == null) return;

      final topicId = _topicManager.currentTopic!.id;
      final result = await _smartContext.compressHistory(
        messages: _llmMessages,
        topicId: topicId,
      );

      if (result.wasCompressed) {
        _llmMessages.clear();
        _llmMessages.addAll(result.messages);
        debugPrint('[AppState] 对话历史已压缩: ${result.messages.length} 条消息');
      }
    } catch (e) {
      debugPrint('[AppState] 压缩对话历史失败: $e');
      // 不影响主流程
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

  /// 生成 LLM 回复（供 ChatBotService 调用）
  Future<String?> generateLLMResponse(String message, List<Map<String, String>> history) async {
    return generateLLMResponseWithImages(message, history, null);
  }
  
  /// 生成 LLM 回复（支持多模态）
  Future<String?> generateLLMResponseWithImages(
    String message,
    List<Map<String, String>> history,
    List<String>? imagePaths,  // 图片路径列表（本地路径或 base64）
  ) async {
    final logger = LLMLoggerService();
    
    if (_llmProvider == null) {
      debugPrint('[AppState] LLM Provider 未配置');
      logger.logError(error: 'LLM Provider 未配置');
      return null;
    }

    try {
      // 构建对话历史
      final messages = <ChatMessage>[];

      // 添加系统提示
      messages.add(ChatMessage.system(
        '你是小紫霞智能助手。当用户问天气、翻译、计算等问题时，即使你没有实时数据工具，'
        '也要尽力用你的知识回答，或者告诉用户你目前无法获取实时数据但可以提供一些建议。'
        '不要说"我无法获取"，而是尽量提供有帮助的信息。'
        '回复要简洁友好。'
      ));

      // 添加历史消息
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          messages.add(ChatMessage(
            role: role == 'assistant' ? MessageRole.assistant : MessageRole.user,
            content: content,
          ));
        }
      }

      // 添加当前消息（可能包含图片）
      final hasImages = imagePaths != null && imagePaths.isNotEmpty && llmConfig!.isVisionModel;
      
      if (hasImages) {
        // 多模态消息
        final images = imagePaths.map((path) {
          // 如果是 base64 数据 URI，直接使用
          if (path.startsWith('data:')) {
            return <String, dynamic>{'url': path};
          }
          // 否则假设是 base64 字符串
          return <String, dynamic>{'url': 'data:image/jpeg;base64,$path'};
        }).toList();
        
        messages.add(ChatMessage.multimodal(text: message, images: images));
        debugPrint('[AppState] 发送多模态消息: ${images.length} 张图片');
      } else {
        // 普通文本消息
        messages.add(ChatMessage(role: MessageRole.user, content: message));
      }

      // 📤 记录请求
      logger.logRequest(
        provider: llmConfig?.provider ?? 'unknown',
        model: llmConfig?.model ?? 'unknown',
        messages: messages.map((m) => {
          'role': m.role.name,
          'content': m.content,
          'isMultimodal': m.isMultimodal,
          'imageCount': m.images?.length ?? 0,
        }).toList(),
      );

      // 调用 LLM
      final response = await _llmProvider!.chat(messages);
      
      // 📥 记录响应
      logger.logResponse(
        content: response.content,
        status: response.finishReason ?? 'success',
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
      );
      
      return response.content;
    } catch (e, stackTrace) {
      debugPrint('[AppState] LLM 生成失败: $e');
      logger.logError(error: e.toString(), stackTrace: stackTrace);
      return null;
    }
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

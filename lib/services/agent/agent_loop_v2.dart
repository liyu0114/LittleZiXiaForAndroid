// Agent Loop 服务 v2 - 学习 ApkClaw 架构
//
// 核心改进：
// 1. 使用 LLM 原生 function calling（不再解析 ```tool``` 格式）
// 2. 上下文压缩（大输出工具结果压缩为摘要）
// 3. 死循环检测（滑动窗口指纹）
// 4. LLM 调用重试（指数退避）

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../memory/memory_service.dart';

/// Agent 状态
enum AgentState {
  idle,
  thinking,
  acting,
  completed,
  failed,
}

/// 工具执行结果
class AgentToolResult {
  final bool isSuccess;
  final String data;
  final String? error;

  AgentToolResult.success(this.data)
      : isSuccess = true,
        error = null;
  AgentToolResult.fail(this.error)
      : isSuccess = false,
        data = '';
}

/// Agent 执行结果
class AgentResult {
  final bool success;
  final String content;
  final int iterations;
  final String? error;

  AgentResult({
    required this.success,
    required this.content,
    this.iterations = 0,
    this.error,
  });
}

/// 循环指纹
class _RoundFingerprint {
  final int observationHash;
  final String toolCall;

  _RoundFingerprint(this.observationHash, this.toolCall);

  @override
  bool operator ==(Object other) =>
      other is _RoundFingerprint &&
      other.observationHash == observationHash &&
      other.toolCall == toolCall;

  @override
  int get hashCode => Object.hash(observationHash, toolCall);
}

/// 可注册的工具
abstract class AgentTool {
  /// 工具名称
  String get name;

  /// 工具描述
  String get description;

  /// JSON Schema 格式的参数定义
  Map<String, dynamic> get parametersSchema;

  /// 执行工具
  Future<AgentToolResult> execute(Map<String, dynamic> arguments);

  /// 转换为 ToolDefinition
  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: description,
      parameters: parametersSchema,
    );
  }
}

/// Agent Loop 服务 v2
class AgentLoopServiceV2 extends ChangeNotifier {
  static final AgentLoopServiceV2 _instance = AgentLoopServiceV2._internal();
  factory AgentLoopServiceV2() => _instance;
  AgentLoopServiceV2._internal();

  // 依赖
  LLMProvider? _llmProvider;
  MemoryService? _memoryService;

  // 工具注册表
  final Map<String, AgentTool> _tools = {};

  // 状态
  AgentState _state = AgentState.idle;
  String _currentTask = '';
  int _iteration = 0;

  // 配置
  int _maxIterations = 10;
  int _maxApiRetries = 3;
  int _loopDetectWindow = 4;

  // 大输出工具 → 压缩占位符
  final Map<String, String> _observationPlaceholders = {};

  // 保护区：最近 N 轮完整保留
  final int _keepRecentRounds = 3;

  // 工具调用回调（用于 UI 实时展示）
  void Function(String toolName, Map<String, dynamic> args)? onToolCall;
  void Function(String toolName, bool success, String? result)? onToolResult;

  AgentState get state => _state;
  String get currentTask => _currentTask;
  bool get isRunning => _state == AgentState.thinking || _state == AgentState.acting;

  /// 注册工具
  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
    debugPrint('[AgentLoopV2] 注册工具: ${tool.name}');
  }

  /// 批量注册工具
  void registerTools(List<AgentTool> tools) {
    for (final tool in tools) {
      registerTool(tool);
    }
  }

  /// 注销工具
  void unregisterTool(String name) {
    _tools.remove(name);
  }

  /// 初始化
  void initialize({
    required LLMProvider llmProvider,
    MemoryService? memoryService,
    int maxIterations = 10,
  }) {
    _llmProvider = llmProvider;
    _memoryService = memoryService;
    _maxIterations = maxIterations;
    debugPrint('[AgentLoopV2] 初始化完成, 已注册 ${_tools.length} 个工具');
  }

  /// 更新 LLM Provider
  void updateProvider(LLMProvider provider) {
    _llmProvider = provider;
  }

  /// 执行任务（主入口）
  Future<AgentResult> execute(String task) async {
    if (_llmProvider == null) {
      return AgentResult(success: false, content: '', error: 'LLM 未配置');
    }
    if (_tools.isEmpty) {
      return AgentResult(success: false, content: '', error: '没有注册任何工具');
    }

    debugPrint('[AgentLoopV2] ========== 开始执行任务 ==========');
    debugPrint('[AgentLoopV2] 任务: $task');

    _currentTask = task;
    _state = AgentState.thinking;
    _iteration = 0;
    notifyListeners();

    try {
      // 整体超时 3 分钟
      return await _runLoop(task).timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          debugPrint('[AgentLoopV2] ⚠️ 整体超时！');
          _state = AgentState.failed;
          notifyListeners();
          return AgentResult(
            success: false,
            content: '',
            error: '执行超时（3分钟），请简化任务或重试',
            iterations: _iteration,
          );
        },
      );
    } catch (e) {
      _state = AgentState.failed;
      notifyListeners();
      return AgentResult(
        success: false,
        content: '',
        error: 'Agent 执行失败: $e',
        iterations: _iteration,
      );
    }
  }

  /// 停止执行
  void stop() {
    _state = AgentState.idle;
    _currentTask = '';
    notifyListeners();
  }

  // ==================== 核心循环 ====================

  Future<AgentResult> _runLoop(String task) async {
    // 构建初始消息
    final messages = <ChatMessage>[
      ChatMessage.system(_buildSystemPrompt()),
      ChatMessage.user(task),
    ];

    // 工具定义
    final toolDefs = _tools.values.map((t) => t.toToolDefinition()).toList();

    // 循环检测
    final loopHistory = <_RoundFingerprint>[];
    int lastObservationHash = 0;

    while (_iteration < _maxIterations) {
      _iteration++;
      _state = AgentState.thinking;
      notifyListeners();

      debugPrint('[AgentLoopV2] ----- 迭代 $_iteration/$_maxIterations -----');

      // 1. 调用 LLM（带重试）
      final llmResponse = await _chatWithRetry(messages, toolDefs);
      if (llmResponse == null) {
        _state = AgentState.failed;
        notifyListeners();
        return AgentResult(
          success: false,
          content: '',
          error: 'LLM 调用失败（重试 $_maxApiRetries 次后）',
          iterations: _iteration,
        );
      }

      final aiContent = llmResponse.content ?? '';

      // 添加 AI 消息到历史
      messages.add(ChatMessage(
        role: MessageRole.assistant,
        content: aiContent,
      ));

      // 2. 检查是否有工具调用
      var callsList = _extractToolCalls(llmResponse);
      
      // 回退：如果 LLM 不支持 function calling，尝试从文本中解析工具调用
      if (callsList.isEmpty && aiContent.isNotEmpty) {
        callsList = _tryParseTextToolCalls(aiContent);
      }
      
      if (callsList.isEmpty) {
        // 没有工具调用 → 任务完成
        _state = AgentState.completed;
        notifyListeners();
        debugPrint('[AgentLoopV2] ✓ 任务完成 (迭代 $_iteration)');
        return AgentResult(
          success: true,
          content: aiContent,
          iterations: _iteration,
        );
      }

      // 执行工具调用
      _state = AgentState.acting;
      notifyListeners();

      for (final call in callsList) {
        final toolName = call['function']?['name'] ?? call['name'] ?? '';
        final toolArgsStr = call['function']?['arguments'] ?? '{}';
        final toolCallId = call['id'] ?? '';

        Map<String, dynamic> toolArgs;
        try {
          toolArgs = Map<String, dynamic>.from(
            jsonDecode(toolArgsStr is String ? toolArgsStr : jsonEncode(toolArgsStr)),
          );
        } catch (_) {
          toolArgs = {};
        }

        debugPrint('[AgentLoopV2] 执行工具: $toolName(${_truncateArgs(toolArgs)})');

        // 回调：工具开始执行
        onToolCall?.call(toolName, toolArgs);

        // 执行
        final result = await _executeTool(toolName, toolArgs);
        final resultJson = jsonEncode({
          'isSuccess': result.isSuccess,
          if (result.isSuccess) 'data': result.data,
          if (!result.isSuccess) 'error': result.error,
        });

        // 记录指纹用于死循环检测
        if (toolName != 'finish') {
          loopHistory.add(_RoundFingerprint(lastObservationHash, '$toolName:$toolArgsStr'));
          if (loopHistory.length > _loopDetectWindow) {
            loopHistory.removeAt(0);
          }
        }

        // finish 工具 → 直接返回
        if (toolName == 'finish' && result.isSuccess) {
          _state = AgentState.completed;
          notifyListeners();
          return AgentResult(
            success: true,
            content: result.data,
            iterations: _iteration,
          );
        }

        // 添加工具结果到历史
        messages.add(ChatMessage(
          role: MessageRole.tool,
          content: resultJson,
          toolCallId: toolCallId,
          name: toolName,
        ));

        debugPrint('[AgentLoopV2] 工具结果: ${result.isSuccess ? "✓" : "✗"} ${_truncate(result.data ?? result.error ?? "", 100)}');

        // 回调：工具执行完成
        onToolResult?.call(toolName, result.isSuccess, result.isSuccess ? result.data : result.error);
      }

      // 3. 死循环检测
      if (_isStuckInLoop(loopHistory)) {
        debugPrint('[AgentLoopV2] ⚠️ 死循环检测！');
        messages.add(ChatMessage.user(
          '[系统提示] 检测到你连续多轮执行了相同的操作且结果相同，可能陷入死循环。'
          '请尝试完全不同的方法，或调用 finish 说明无法完成的原因。',
        ));
        loopHistory.clear();
      }

      // 4. 上下文压缩
      _compressHistory(messages);
    }

    // 超过最大迭代
    _state = AgentState.failed;
    notifyListeners();
    return AgentResult(
      success: false,
      content: '',
      error: '超过最大迭代次数 ($_maxIterations)',
      iterations: _iteration,
    );
  }

  // ==================== LLM 调用（带重试）====================

  Future<LLMResponse?> _chatWithRetry(
    List<ChatMessage> messages,
    List<ToolDefinition> tools,
  ) async {
    Exception? lastException;

    for (int attempt = 0; attempt < _maxApiRetries; attempt++) {
      try {
        final response = await _llmProvider!.chat(messages, tools: tools);
        return response;
      } catch (e) {
        lastException = e as Exception;
        final msg = e.toString();

        // 401/403 不重试
        if (msg.contains('401') || msg.contains('403')) {
          debugPrint('[AgentLoopV2] 认证失败，不重试: $msg');
          return null;
        }

        final delay = Duration(seconds: 1 << attempt); // 1s, 2s, 4s
        debugPrint('[AgentLoopV2] LLM 调用失败 (${attempt + 1}/$_maxApiRetries)，${delay.inSeconds}s 后重试: $msg');
        await Future.delayed(delay);
      }
    }

    debugPrint('[AgentLoopV2] LLM 调用失败，已耗尽重试次数');
    return null;
  }

  // ==================== 工具调用提取 ====================

  List<Map<String, dynamic>> _extractToolCalls(LLMResponse response) {
    final calls = <Map<String, dynamic>>[];
    final raw = response.toolCalls;
    if (raw == null) return calls;

    // OpenAI/GLM 格式：tool_calls 是一个 List
    if (raw is List) {
      for (final call in raw) {
        if (call is Map) {
          calls.add(Map<String, dynamic>.from(call));
        }
      }
      return calls;
    }

    // 兼容：raw 是 Map 的情况
    if (raw is Map) {
      // 可能是 {tool_calls: [...]}
      if (raw.containsKey('tool_calls')) {
        final tc = raw['tool_calls'];
        if (tc is List) {
          for (final call in tc) {
            if (call is Map) {
              calls.add(Map<String, dynamic>.from(call));
            }
          }
        }
        return calls;
      }
      // 单个工具调用格式 {function: {...}}
      if (raw.containsKey('function')) {
        calls.add(Map<String, dynamic>.from(raw));
      }
    }

    return calls;
  }

  // ==================== 文本工具调用解析（回退）====================

  /// 当 LLM 不支持 function calling 时，尝试从文本中解析工具调用
  /// 支持格式：
  /// - ```tool\n{"name": "web_search", "arguments": {"query": "xxx"}}\n```
  /// - [调用 web_search(query="xxx")]
  /// - 工具调用: web_search({"query": "xxx"})
  List<Map<String, dynamic>> _tryParseTextToolCalls(String content) {
    final calls = <Map<String, dynamic>>[];
    
    // 格式1: ```tool ... ``` 代码块
    final toolBlockRegex = RegExp(r'```tool\s*\n([\s\S]*?)\n```');
    for (final match in toolBlockRegex.allMatches(content)) {
      try {
        final json = jsonDecode(match.group(1)!);
        if (json is Map) {
          final name = json['name'] as String? ?? json['tool'] as String?;
          if (name != null && _tools.containsKey(name)) {
            calls.add({
              'id': 'text_call_${calls.length}',
              'function': {
                'name': name,
                'arguments': jsonEncode(json['arguments'] ?? json['params'] ?? {}),
              },
            });
          }
        }
      } catch (_) {}
    }
    if (calls.isNotEmpty) return calls;
    
    // 格式2: [调用 tool_name(args)] 或 工具调用: tool_name(args)
    final callRegex = RegExp(r'(?:调用|工具调用|call)\s*:\s*(\w+)\s*\((.*?)\)', caseSensitive: false);
    for (final match in callRegex.allMatches(content)) {
      final name = match.group(1);
      if (name != null && _tools.containsKey(name)) {
        final argsStr = match.group(2) ?? '{}';
        Map<String, dynamic> args;
        try {
          args = Map<String, dynamic>.from(jsonDecode(argsStr));
        } catch (_) {
          // 尝试 key=value 格式
          args = {};
          for (final pair in argsStr.split(',')) {
            final kv = pair.split('=');
            if (kv.length == 2) {
              args[kv[0].trim()] = kv[1].trim().replaceAll('"', '').replaceAll("'", '');
            }
          }
        }
        calls.add({
          'id': 'text_call_${calls.length}',
          'function': {
            'name': name,
            'arguments': jsonEncode(args),
          },
        });
      }
    }
    
    return calls;
  }

  // ==================== 工具执行 ====================

  Future<AgentToolResult> _executeTool(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return AgentToolResult.fail('未知工具: $name');
    }

    try {
      return await tool.execute(args);
    } catch (e) {
      return AgentToolResult.fail('工具执行失败: $e');
    }
  }

  // ==================== 死循环检测 ====================

  bool _isStuckInLoop(List<_RoundFingerprint> history) {
    if (history.length < _loopDetectWindow) return false;
    final first = history.first;
    return history.every((fp) => fp == first);
  }

  // ==================== 上下文压缩 ====================

  /// 压缩历史消息，节省 token
  /// 策略（学习 ApkClaw）：
  /// - 观察类大输出工具：全局只保留最新一条
  /// - 保护区（最近 N 轮）：完整保留
  /// - 保护区外：压缩为摘要
  void _compressHistory(List<ChatMessage> messages) {
    if (messages.length < 10) return; // 消息太少不压缩

    // 找出所有 tool result 消息
    final toolResults = <int, ChatMessage>{};
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].role == MessageRole.tool) {
        toolResults[i] = messages[i];
      }
    }

    // 只处理超过 200 字符的 tool result
    for (final entry in toolResults.entries) {
      final idx = entry.key;
      final msg = entry.value;
      if (msg.content.length <= 200) continue;

      // 检查是否有对应的占位符
      final toolName = msg.name ?? '';
      if (_observationPlaceholders.containsKey(toolName)) {
        // 全局只保留最新一条
        final lastIdx = toolResults.entries
            .where((e) => e.value.name == toolName)
            .map((e) => e.key)
            .reduce((a, b) => a > b ? a : b);

        if (idx != lastIdx) {
          // 替换为占位符
          messages[idx] = ChatMessage(
            role: MessageRole.tool,
            content: _observationPlaceholders[toolName]!,
            toolCallId: msg.toolCallId,
            name: msg.name,
          );
        }
      }
    }
  }

  // ==================== System Prompt ====================

  String _buildSystemPrompt() {
    final toolsDesc = _tools.values.map((t) {
      return '- **${t.name}**: ${t.description}';
    }).join('\n');

    final hasCodeTools = _tools.containsKey('create_code_project') || _tools.containsKey('update_code_file');
    final codeGuidance = hasCodeTools ? '''

## 代码开发指南
当用户要求创建程序（计算器、游戏、工具等）时：
1. 调用 `create_code_project` 工具，在 `code` 参数中提供**完整可用的 HTML 代码**（包含 CSS 和 JavaScript）
2. 代码必须是完整独立的 HTML 文件，可以直接在浏览器/WebView 中运行
3. 界面要美观、交互要完整、功能要实用
4. 不要只给空壳模板，要实现用户要求的全部功能
5. 如果用户要求修改已有项目，先调用 `list_code_projects` 查看，再调用 `update_code_file` 修改

示例：用户说"帮我做一个计算器"
→ 调用 create_code_project，name="计算器"，code=一个包含完整计算器 UI 和 JS 逻辑的 HTML 文件
''' : '';

    final hasWebSearch = _tools.containsKey('web_search');
    final webGuidance = hasWebSearch ? '''

## 联网搜索指南
当你需要获取实时信息（天气、新闻、时事、价格、最新数据等）时：
1. 优先调用 `web_search` 搜索相关信息
2. 如果搜索结果中的链接看起来有用，可以调用 `web_fetch` 获取详细内容
3. 综合搜索结果，用你自己的语言整理回答用户
4. 不要逐条罗列搜索结果，要提炼要点
''' : '';

    final hasSkillHub = _tools.containsKey('skill_hub_search');
    final skillHubGuidance = hasSkillHub ? '''

## 工具发现与扩展（重要！）
当你发现当前工具不足以完成用户任务时，不要直接说"做不到"。按以下优先级尝试：

### 1. 搜索新技能
调用 `skill_hub_search` 在技能市场搜索可能存在的新工具。
例如：用户要查汇率 → 搜索 "exchange rate"；用户要翻译 → 搜索 "translate"。

### 2. 安装新技能
如果搜索到了合适的技能，调用 `skill_hub_install` 安装它。
安装成功后，新技能会立即可用，你可以直接在下一轮调用它。

### 3. 自己写代码
如果技能市场也没有合适的工具，调用 `run_script` 自己写 JS/HTML 代码解决问题。
你可以写代码来：调用外部 API、做复杂计算、处理数据、生成图表等。

**核心原则：永远先尝试用工具解决，不要轻易说"我做不到"。**
''' : '';

    return '''你是小紫霞智能助手，具备自主执行任务的能力。
$skillHubGuidance

## 工作模式
你按照以下循环工作：
1. **观察** → 分析当前状态和已有信息
2. **思考** → 规划下一步行动
3. **行动** → 调用合适的工具执行
4. **验证** → 检查结果，决定继续还是完成

## 核心原则
- 先理解意图，再行动
- 每次只做一步，观察结果再决定下一步
- 遇到失败尝试不同方法
- 任务完成后立即回复用户，不要多余操作
- **自主解决问题**：如果某个工具不可用，尝试其他方式完成任务（如 Skill 不可用时用 web_search）
- **不要说做不到**：尽力用已有工具完成，实在不行才告诉用户限制
$codeGuidance$webGuidance
## 可用工具
$toolsDesc

## 完成任务
当任务完成时，直接回复用户，不要调用工具。
如果无法完成，说明原因和建议的替代方案。

## 安全约束
- 不执行破坏性操作
- 不自动填写支付信息
- 遇到需要登录的操作，通知用户
''';
  }

  // ==================== 辅助方法 ====================

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  String _truncateArgs(Map<String, dynamic> args) {
    final str = args.toString();
    return _truncate(str, 80);
  }

  /// 设置观察类工具的占位符（用于上下文压缩）
  void setPlaceholder(String toolName, String placeholder) {
    _observationPlaceholders[toolName] = placeholder;
  }

  /// 获取已注册工具列表
  List<AgentTool> get registeredTools => _tools.values.toList();

  /// 获取工具定义列表
  List<ToolDefinition> get toolDefinitions =>
      _tools.values.map((t) => t.toToolDefinition()).toList();
}

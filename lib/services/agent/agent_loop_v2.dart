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
import 'task_state_service.dart';

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
  final TaskStateService _taskState = TaskStateService();

  // 工具注册表
  final Map<String, AgentTool> _tools = {};

  // 状态
  AgentState _state = AgentState.idle;
  String _currentTask = '';
  int _iteration = 0;

  // 配置
  int _maxIterations = 15;
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
  Future<AgentResult> execute(String task, {TaskSnapshot? resumeFrom}) async {
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
      return await _runLoop(task, resumeFrom: resumeFrom).timeout(
        const Duration(minutes: 3),
        onTimeout: () async {
          debugPrint('[AgentLoopV2] ⚠️ 整体超时！');
          _state = AgentState.failed;
          notifyListeners();
          
          // 保存失败快照，供恢复用
          await _saveCurrentSnapshot(task, 'failed', error: '执行超时（3分钟），请简化任务或重试');
          
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
      
      // 保存异常快照
      await _saveCurrentSnapshot(task, 'failed', error: 'Agent 执行失败: $e');
      
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

  /// 意图预路由：通用版本，只处理位置依赖等真正需要预路由的场景
  /// 不硬编码具体问题类型，让 LLM 自己根据可用工具决策
  String _routeIntent(String task) {
    final lower = task.toLowerCase();
    final hints = <String>[];

    // 位置依赖：用户提到当前位置时，提示先获取位置
    if (lower.contains('我这') || lower.contains('附近') || lower.contains('这里') ||
        lower.contains('当地') || lower.contains('从这') || lower.contains('本地') ||
        lower.contains('我所在') || lower.contains('我这儿')) {
      if (_tools.containsKey('get_location')) {
        hints.add('[系统提示：用户提到了当前位置相关的意图，请先调用 get_location 获取位置信息，再执行后续任务。]');
      }
    }

    if (hints.isEmpty) return task;
    return '${hints.join('\n')}\n\n用户消息：$task';
  }

  Future<AgentResult> _runLoop(String task, {TaskSnapshot? resumeFrom}) async {
    // 意图预路由：检测常见意图，注入工具提示
    final routedTask = _routeIntent(task);

    // 构建初始消息（支持从快照恢复）
    final messages = <ChatMessage>[];
    if (resumeFrom != null && resumeFrom.messages.isNotEmpty) {
      // 从快照恢复对话历史
      debugPrint('[AgentLoopV2] 从快照恢复: ${resumeFrom.messages.length} 条历史消息');
      for (final msgJson in resumeFrom.messages) {
        try {
          messages.add(ChatMessage.fromJson(msgJson));
        } catch (_) {
          // 跳过无法解析的消息
        }
      }
      // 注入恢复提示
      messages.add(ChatMessage.user(
        '[系统提示] 刚才的任务执行中断了。以下是之前收集的信息：\n'
        '${resumeFrom.toolResults.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}\n\n'
        '请根据已有信息继续完成用户的原始任务: ${resumeFrom.originalTask}\n'
        '不要重复之前已经做过的步骤，直接继续。',
      ));
      _iteration = resumeFrom.iteration;
    } else {
      messages.addAll([
        ChatMessage.system(_buildSystemPrompt()),
        ChatMessage.user(routedTask),
      ]);
    }

    // 工具定义
    final toolDefs = _tools.values.map((t) => t.toToolDefinition()).toList();

    // 任务状态追踪（用于快照保存）
    _currentTaskId = resumeFrom?.taskId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _currentMessages = messages;
    _currentToolResults.clear();

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
        // 没有工具调用 → 检查是否因为缺少信息/工具而放弃
        if (_looksLikeGivingUp(aiContent) && _hasSkillHub) {
          // LLM 在向用户要信息而不是用工具获取 → 引导它去 SkillHub 找工具
          debugPrint('[AgentLoopV2] ⚠️ LLM 放弃了，尝试引导搜索技能...');
          messages.add(ChatMessage(
            role: MessageRole.user,
            content: '你刚才没有调用任何工具就直接回复了。'
                '请按以下顺序尝试：\n'
                '1. 先调用 skill_hub_search 搜索可能存在的技能\n'
                '2. 如果找到了，用 skill_hub_install 安装\n'
                '3. 如果没有找到合适的技能，用 web_search 搜索相关信息\n'
                '4. 如果以上都不行，用 run_script 自己写代码解决\n'
                '5. 如果真的搞不定，调用 ask_user 向用户说明情况并协商替代方案\n'
                '不要向用户要信息——主动用工具获取！',
          ));
          continue; // 继续循环，给 LLM 另一次机会
        }

        // 即使没有 SkillHub，LLM 放弃时也引导它用其他工具
        if (_looksLikeGivingUp(aiContent) && !_hasSkillHub) {
          debugPrint('[AgentLoopV2] ⚠️ LLM 放弃了，引导使用其他工具...');
          messages.add(ChatMessage(
            role: MessageRole.user,
            content: '你刚才没有调用任何工具就直接回复了。'
                '请检查可用工具列表，用 web_search 搜索相关信息，或用 run_script 写代码解决。'
                '如果确实无法完成，请调用 ask_user 向用户说明情况并协商替代方案。'
                '禁止直接说"我做不到"就结束！',
          ));
          continue;
        }

        // 真正完成任务
        _state = AgentState.completed;
        notifyListeners();
        debugPrint('[AgentLoopV2] ✓ 任务完成 (迭代 $_iteration)');
        return AgentResult(
          success: true,
          content: aiContent,
          iterations: _iteration,
        );
      }

      // 接近迭代上限时，强制收尾：执行完这轮工具后不再继续
      if (_iteration >= _maxIterations - 1) {
        debugPrint('[AgentLoopV2] ⚠️ 接近迭代上限，执行最后一轮工具后强制收尾');

        // 执行这轮工具调用
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

          onToolCall?.call(toolName, toolArgs);
          final result = await _executeTool(toolName, toolArgs);
          final resultJson = jsonEncode({
            'isSuccess': result.isSuccess,
            if (result.isSuccess) 'data': result.data,
            if (!result.isSuccess) 'error': result.error,
          });

          messages.add(ChatMessage(
            role: MessageRole.tool,
            content: resultJson,
            toolCallId: toolCallId,
            name: toolName,
          ));

          onToolResult?.call(toolName, result.isSuccess, result.isSuccess ? result.data : result.error);
        }

        // 强制收尾：让 LLM 用已有信息生成最终回复
        messages.add(ChatMessage(
          role: MessageRole.user,
          content: '[系统强制收尾] 你已经执行了很多步骤，现在必须立即给用户一个最终回复。'
              '根据你目前收集到的所有信息，直接回答用户的问题。'
              '不要再调用任何工具。直接给出完整的最终答案。',
        ));

        // 最后一轮 LLM 调用（不带工具）
        final finalResponse = await _chatWithRetry(messages, []);
        if (finalResponse != null && (finalResponse.content ?? '').isNotEmpty) {
          _state = AgentState.completed;
          notifyListeners();
          return AgentResult(
            success: true,
            content: finalResponse.content!,
            iterations: _iteration,
          );
        }

        // 即使 LLM 最后调用也失败了，用已有信息拼一个回复
        _state = AgentState.completed;
        notifyListeners();
        return AgentResult(
          success: true,
          content: _buildFallbackResponse(messages),
          iterations: _iteration,
        );
      }

      // 正常执行工具调用
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

        // 收集工具结果用于快照
        final resultStr = result.isSuccess ? (result.data ?? '') : (result.error ?? '');
        _currentToolResults[toolName] = _truncate(resultStr, 200);

        // 回调：工具执行完成
        onToolResult?.call(toolName, result.isSuccess, result.isSuccess ? result.data : result.error);
      }

      // 3. 死循环检测
      if (_isStuckInLoop(loopHistory)) {
        debugPrint('[AgentLoopV2] ⚠️ 死循环检测！');
        messages.add(ChatMessage.user(
          '[系统提示] 检测到你连续多轮执行了相同的操作且结果相同，可能陷入死循环。'
          '请立即换一种完全不同的方法。如果你一直在尝试获取某个信息但失败了，'
          '请用 web_search 直接搜索用户的问题，或者用你自己的知识回答。'
          '不要继续重复失败的尝试。',
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
      content: _buildFallbackResponse(messages),
      error: '超过最大迭代次数 ($_maxIterations)，但已根据收集到的信息生成回复',
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

  // ==================== 智能兜底：检测 LLM 是否在"放弃" ====================

  /// 是否有 SkillHub 搜索和安装工具
  bool get _hasSkillHub =>
      _tools.containsKey('skill_hub_search') && _tools.containsKey('skill_hub_install');

  /// 检测 LLM 回复是否像是在"放弃"（向用户要信息而不是用工具获取）
  bool _looksLikeGivingUp(String content) {
    if (content.isEmpty) return false;
    final lower = content.toLowerCase();

    // 中文信号词：向用户要信息
    final giveUpPatterns = [
      '请告诉我',
      '请问你',
      '你能告诉我',
      '请提供',
      '需要知道',
      '需要您',
      '你能说',
      '请说明',
      '我无法',
      '我没有',
      '我需要你',
      '我缺少',
      '如果你能',
      'which city',
      'please tell',
      'can you tell',
      'please provide',
      'i need to know',
      'i cannot',
    ];

    return giveUpPatterns.any((p) => lower.contains(p));
  }

  // ==================== 兜底回复 ====================

  /// 从已收集的信息中构建兜底回复
  String _buildFallbackResponse(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    buffer.writeln('根据已收集到的信息：');
    buffer.writeln();

    // 从工具结果中提取有用信息
    for (final msg in messages) {
      if (msg.role == MessageRole.tool && msg.content != null) {
        try {
          final json = jsonDecode(msg.content!);
          if (json is Map && json['isSuccess'] == true && json['data'] != null) {
            final data = json['data'] as String;
            if (data.isNotEmpty && data.length < 2000) {
              buffer.writeln(data);
              buffer.writeln();
            }
          }
        } catch (_) {
          // 不是 JSON，直接用
          if (msg.content != null && msg.content!.length < 2000) {
            buffer.writeln(msg.content);
            buffer.writeln();
          }
        }
      }
    }

    if (buffer.length > 50) {
      return buffer.toString().trim();
    }

    return '抱歉，我在处理这个任务时遇到了一些困难，没能完全完成。请换个方式描述你的需求，我会再试一次。';
  }

  // ==================== System Prompt ====================

  String _buildSystemPrompt() {
    final toolsDesc = _tools.values.map((t) {
      return '- **${t.name}**: ${t.description}';
    }).join('\n');

    return '''你是小紫霞智能助手，一个具备工具调用能力的 AI Agent。

## 核心身份
你不是一个纯文本 AI。你拥有工具，可以主动获取信息、执行操作、解决问题。
你的目标是用工具获取准确信息，而不是凭记忆猜测。

## 🚨 通用问题解决框架（适用所有问题）

收到任何问题时，严格按以下流程处理：

### Step 1: 理解意图
- 用户想要什么结果？
- 需要哪些信息才能给出答案？
- 有没有隐含的依赖（如位置、时间、上下文）？

### Step 2: 检查工具
- 查看下面的可用工具列表
- 哪些工具能获取我需要的信息？
- 如果当前工具不够，先搜索安装新工具（skill_hub_search → skill_hub_install）
- 用户说"我这/这里/当地/附近" → 必须先调用 get_location

### Step 3: 规划并执行
- 列出需要调用的工具和顺序
- 每次只做一步，观察结果后决定下一步
- 如果工具 A 失败 → 换工具 B（如 skill 失败 → web_fetch）
- 如果需要新工具 → skill_hub_search + skill_hub_install

### Step 4: 整理并回答
- 用工具获取的数据给用户一个清晰、准确的答案
- 不要重复展示原始 JSON 或技术日志
- 标注数据来源和时间

## 🔧 失败处理（永不放弃）

遇到失败时，按以下顺序尝试：
1. **分析原因** — 参数错误？工具不可用？缺少前置信息？
2. **换方法** — 工具 A 不行换工具 B，方法 X 不行试方法 Y
3. **搜索新工具** — skill_hub_search 找新技能，skill_hub_install 安装
4. **自己写代码** — 用 run_script 写 JS 脚本解决问题
5. **联网搜索** — web_search + web_fetch 获取信息
6. **协商** — 如果以上都不行，用 ask_user 和用户商量替代方案

## 🤝 协商规则（重要！）
- 当所有工具都无法完成任务时，必须调用 ask_user
- ask_user 中要说明：遇到什么问题 + 分析原因 + 提出替代方案选项
- 绝对不能直接说"我做不到"就结束
- 如果用户之前已经提供过信息（上下文中有），不要再说"请提供"

## 📝 学习（save_as_skill）

成功完成复杂任务后，主动调用 save_as_skill 保存解决路径，方便下次复用。

## ⛔ 绝对禁止
- **禁止说"我无法获取"而不尝试工具** — 你有工具，先用工具
- **禁止向用户要你可以自己获取的信息**（如位置——用 get_location）
- **禁止连续相同调用** — 说明在死循环，必须换方法
- **禁止没给有用答案就结束**

## 可用工具
$toolsDesc

## 回复要求
- 用中文回复
- 给出明确答案
- 任务完成后考虑用 save_as_skill 记录经验
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

  // ==================== 任务状态持久化 ====================

  /// 当前执行的任务 ID（用于快照关联）
  String? _currentTaskId;

  /// 当前执行中的消息列表引用（用于快照保存）
  List<ChatMessage>? _currentMessages;

  /// 当前执行中的工具结果收集
  final Map<String, String> _currentToolResults = {};

  /// 保存当前执行状态为快照
  Future<void> _saveCurrentSnapshot(String task, String status, {String? error}) async {
    if (_currentMessages == null) return;

    final taskId = _currentTaskId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final messagesJson = _currentMessages!.map((m) => m.toJson()).toList();

    final snapshot = TaskSnapshot(
      taskId: taskId,
      originalTask: task,
      createdAt: DateTime.now().subtract(Duration(seconds: _iteration * 10)),
      updatedAt: DateTime.now(),
      status: status,
      messages: messagesJson,
      iteration: _iteration,
      maxIterations: _maxIterations,
      toolResults: Map.from(_currentToolResults),
      error: error,
      partialResult: _buildFallbackResponse(_currentMessages!),
    );

    await _taskState.saveSnapshot(snapshot);
    debugPrint('[AgentLoopV2] 快照已保存: $taskId ($status)');
  }

  /// 获取最近可恢复的任务
  Future<TaskSnapshot?> getLatestResumableTask() async {
    return await _taskState.getLatestResumable();
  }

  /// 搜索与描述匹配的可恢复任务
  Future<TaskSnapshot?> findRelatedTask(String description) async {
    return await _taskState.findRelatedTask(description);
  }

  /// 尝试恢复一个任务（通用入口）
  /// 当用户说"继续刚才的任务"、"再试一次"等时调用
  Future<AgentResult> resumeTask(String userMessage) async {
    // 1. 尝试找到相关的任务快照
    TaskSnapshot? snapshot = await _taskState.findRelatedTask(userMessage);
    snapshot ??= await _taskState.getLatestResumable();

    if (snapshot == null) {
      // 没有可恢复的任务，正常执行
      return execute(userMessage);
    }

    debugPrint('[AgentLoopV2] 恢复任务: ${snapshot.taskId} - ${snapshot.originalTask}');
    _currentTaskId = snapshot.taskId;

    // 用快照中的信息构造恢复提示
    final resumeTask = '继续完成之前的任务: ${snapshot.originalTask}'
        '\n之前已经执行了 ${snapshot.iteration} 步。'
        '${snapshot.error != null ? '\n上次失败原因: ${snapshot.error}' : ''}'
        '\n请从上次中断的地方继续，不要重复已完成的步骤。';

    return execute(resumeTask, resumeFrom: snapshot);
  }
}

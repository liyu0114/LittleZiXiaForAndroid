// Agent Loop 服务 - OpenClaw 风格
//
// 实现"思考-行动-观察-再思考"的自主执行循环

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../memory/memory_service.dart';
import '../skills/skill_system.dart';
import '../remote/remote_connection.dart';  // 新增

/// Agent 状态
enum AgentState {
  idle,        // 空闲
  thinking,    // 思考中
  acting,      // 执行工具
  observing,   // 观察结果
  completed,   // 完成
  failed,      // 失败
}

/// 工具调用请求
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String? id;

  ToolCall({
    required this.name,
    required this.arguments,
    this.id,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      name: json['name'] ?? json['function']?['name'] ?? '',
      arguments: Map<String, dynamic>.from(json['arguments'] ?? json['function']?['arguments'] ?? {}),
      id: json['id'],
    );
  }
}

/// Agent 执行结果
class AgentResult {
  final bool success;
  final String content;
  final List<Map<String, dynamic>> toolCalls;
  final String? error;

  AgentResult({
    required this.success,
    required this.content,
    this.toolCalls = const [],
    this.error,
  });
}

/// 循环检测配置
class LoopDetectionConfig {
  final bool enabled;
  final int historySize;
  final int repeatThreshold;
  final int criticalThreshold;
  final int cooldownMs;

  LoopDetectionConfig({
    this.enabled = true,
    this.historySize = 20,
    this.repeatThreshold = 3,
    this.criticalThreshold = 6,
    this.cooldownMs = 12000,
  });
}

/// 循环检测结果
enum LoopDetectionResult {
  ok,
  warning,
  critical,
}

/// Agent Loop 服务
class AgentLoopService extends ChangeNotifier {
  static final AgentLoopService _instance = AgentLoopService._internal();
  factory AgentLoopService() => _instance;
  AgentLoopService._internal();

  // 依赖服务
  LLMProvider? _llmProvider;
  MemoryService? _memoryService;
  SkillManager? _skillManager;
  RemoteConnection? _remoteConnection;  // 新增

  // 状态
  AgentState _state = AgentState.idle;
  String _currentTask = '';
  final List<Map<String, dynamic>> _history = [];
  final StringBuffer _observationBuffer = StringBuffer();
  int _iteration = 0;
  final int _maxIterations = 10;
  
  // 循环检测
  final LoopDetectionConfig _loopConfig = LoopDetectionConfig();
  final List<Map<String, dynamic>> _toolCallHistory = [];
  DateTime? _lastLoopWarning;

  // Getters
  AgentState get state => _state;
  String get currentTask => _currentTask;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  /// 初始化
  void initialize({
    required LLMProvider llmProvider,
    MemoryService? memoryService,
    SkillManager? skillManager,
    RemoteConnection? remoteConnection,  // 新增
  }) {
    _llmProvider = llmProvider;
    _memoryService = memoryService;
    _skillManager = skillManager;
    _remoteConnection = remoteConnection;  // 新增
    debugPrint('[AgentLoop] 初始化完成');
  }

  /// 执行任务（主入口）
  Future<AgentResult> execute(String task) async {
    if (_llmProvider == null) {
      return AgentResult(success: false, content: '', error: 'LLM 未配置');
    }

    debugPrint('[AgentLoop] ========== 开始执行任务 ==========');
    debugPrint('[AgentLoop] 任务: $task');

    // 重置状态
    _currentTask = task;
    _state = AgentState.thinking;
    _history.clear();
    _observationBuffer.clear();
    _toolCallHistory.clear();
    _iteration = 0;
    notifyListeners();

    // 开始循环
    return await _runLoop();
  }

  /// Agent Loop 核心
  Future<AgentResult> _runLoop() async {
    while (_iteration < _maxIterations) {
      _iteration++;
      debugPrint('[AgentLoop] ----- 迭代 $_iteration/$_maxIterations -----');

      // 1. 思考阶段
      _state = AgentState.thinking;
      notifyListeners();

      final thinkResult = await _think();
      if (!thinkResult.success) {
        return thinkResult;
      }

      // 2. 检查是否需要执行工具
      if (thinkResult.toolCalls.isEmpty) {
        // 没有工具调用，任务完成
        _state = AgentState.completed;
        notifyListeners();
        return AgentResult(
          success: true,
          content: thinkResult.content,
        );
      }

      // 3. 执行工具
      _state = AgentState.acting;
      notifyListeners();

      for (final toolCall in thinkResult.toolCalls) {
        final toolName = toolCall['name'] ?? toolCall['function']?['name'] ?? '';
        final toolArgs = toolCall['arguments'] ?? toolCall['function']?['arguments'] ?? {};

        debugPrint('[AgentLoop] 执行工具: $toolName, 参数: $toolArgs');

        // 循环检测
        final loopResult = _checkLoop(toolName, toolArgs);
        
        if (loopResult == LoopDetectionResult.critical) {
          final msg = '[循环检测] 检测到重复工具调用，已打断: $toolName';
          debugPrint('[AgentLoop] $msg');
          _lastLoopWarning = DateTime.now();
          return AgentResult(
            success: false,
            content: '',
            error: msg,
          );
        } else if (loopResult == LoopDetectionResult.warning) {
          final repeatCount = _toolCallHistory.where((r) => 
            r['name'] == toolName && 
            _hashArgs(r['arguments'] as Map<String, dynamic>) == _hashArgs(toolArgs)
          ).length;
          
          final msg = '[循环检测] 警告: 可能重复调用 $toolName (重复 $repeatCount 次)';
          debugPrint('[AgentLoop] $msg');
          _lastLoopWarning = DateTime.now();
          // 继续执行，但记录警告
        }

        // 记录到历史
        _history.add({
          'type': 'tool_call',
          'name': toolName,
          'arguments': toolArgs,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // 执行工具
        final toolResult = await _executeTool(toolName, toolArgs);

        // 记录结果
        _history.add({
          'type': 'tool_result',
          'name': toolName,
          'result': toolResult,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // 添加到观察缓冲区
        _observationBuffer.writeln('[工具结果] $toolName:');
        _observationBuffer.writeln(toolResult);
        _observationBuffer.writeln('');
      }

      // 4. 观察阶段
      _state = AgentState.observing;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 100));

      // 继续下一轮迭代
    }

    // 超过最大迭代次数
    _state = AgentState.failed;
    notifyListeners();
    return AgentResult(
      success: false,
      content: _observationBuffer.toString(),
      error: '超过最大迭代次数',
    );
  }

  /// 循环检测
  LoopDetectionResult _checkLoop(String toolName, Map<String, dynamic> arguments) {
    if (!_loopConfig.enabled) {
      return LoopDetectionResult.ok;
    }

    // 添加到工具调用历史
    _toolCallHistory.add({
      'name': toolName,
      'arguments': arguments,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 限制历史大小
    if (_toolCallHistory.length > _loopConfig.historySize) {
      _toolCallHistory.removeAt(0);
    }

    // 检测重复
    int repeatCount = 0;
    final currentKey = '$toolName:${_hashArgs(arguments)}';
    
    for (final record in _toolCallHistory) {
      final recordKey = '${record['name']}:${_hashArgs(record['arguments'] as Map<String, dynamic>)}';
      if (recordKey == currentKey) {
        repeatCount++;
      }
    }

    // 检查冷却时间
    if (_lastLoopWarning != null) {
      final elapsed = DateTime.now().difference(_lastLoopWarning!).inMilliseconds;
      if (elapsed < _loopConfig.cooldownMs) {
        return LoopDetectionResult.ok;
      }
    }

    // 判断结果
    if (repeatCount >= _loopConfig.criticalThreshold) {
      return LoopDetectionResult.critical;
    } else if (repeatCount >= _loopConfig.repeatThreshold) {
      return LoopDetectionResult.warning;
    }

    return LoopDetectionResult.ok;
  }

  /// 参数哈希
  String _hashArgs(Map<String, dynamic> args) {
    final sortedKeys = args.keys.toList()..sort();
    return sortedKeys.map((k) => '$k=${args[k]}').join('&');
  }

  /// 思考阶段
  Future<AgentResult> _think() async {
    // 1. 搜索相关记忆
    String memoryContext = '';
    if (_memoryService != null) {
      final memories = _memoryService!.search(_currentTask, maxResults: 3);
      if (memories.isNotEmpty) {
        memoryContext = '\n## 相关记忆\n';
        for (final m in memories) {
          memoryContext += '- ${m.entry.content}\n';
        }
      }
    }

    // 2. 获取可用工具
    final tools = _getAvailableTools();

    // 3. 构建系统提示
    final systemPrompt = _buildSystemPrompt(tools);

    // 4. 构建用户消息
    final userMessage = _buildUserMessage(memoryContext);

    // 5. 调用 LLM
    final messages = [
      ChatMessage.system(systemPrompt),
      ChatMessage.user(userMessage),
    ];

    final responseBuffer = StringBuffer();
    final stream = _llmProvider!.chatStream(messages);

    await for (final event in stream) {
      if (event.error != null) {
        return AgentResult(success: false, content: '', error: event.error);
      }
      if (event.done) break;
      if (event.delta != null) {
        responseBuffer.write(event.delta);
      }
    }

    final response = responseBuffer.toString();
    debugPrint('[AgentLoop] LLM 响应: $response');

    // 6. 解析响应，提取工具调用
    final toolCalls = _parseToolCalls(response);

    return AgentResult(
      success: true,
      content: response,
      toolCalls: toolCalls,
    );
  }

  /// 构建系统提示
  String _buildSystemPrompt(List<Map<String, dynamic>> tools) {
    final toolsJson = const JsonEncoder.withIndent('  ').convert(tools);

    return '''你是小紫霞智能助手，能够自主完成复杂任务。

## 核心能力
- 你可以调用工具来完成任务
- 你可以自主决定如何分解复杂任务
- 你会在多轮循环中持续工作，直到任务完成

## 工作原则
1. **理解意图**：先理解用户真正想要什么，不要急于执行
2. **规划优先**：复杂任务先在心中规划步骤，再逐步执行
3. **观察反馈**：每次工具调用后，仔细观察结果，决定下一步
4. **灵活应变**：遇到失败要尝试不同方法，不要重复相同操作
5. **及时收尾**：任务完成后直接回复用户，不要继续调用工具

## 循环检测（重要）
系统会检测重复的工具调用：
- 同一工具 + 相同参数 连续 3 次 → 警告
- 连续 6 次 → 强制中断

如果发现自己在循环，立即：
- 换一个方法
- 简化任务
- 或直接告诉用户遇到困难

## 可用工具
$toolsJson

## 调用格式
当需要调用工具时，返回以下格式（注意是单行JSON）：

```tool
{"name": "工具名", "arguments": {"参数1": "值1", "参数2": "值2"}}
```

## 示例对话

用户：帮我查一下北京和上海的天气，然后对比

助手思考：
1. 需要调用两次天气工具
2. 然后对比结果

助手行动：
```tool
{"name": "skill_weather", "arguments": {"location": "北京"}}
```

系统返回：北京今天晴，15-25°C

助手行动：
```tool
{"name": "skill_weather", "arguments": {"location": "上海"}}
```

系统返回：上海今天多云，18-26°C

助手回复：
北京今天晴天，气温 15-25°C；上海多云，气温 18-26°C。
对比：上海比北京稍暖，但北京天气更好适合户外活动。

---

现在开始工作。记住：理解意图 → 规划步骤 → 执行 → 观察结果 → 继续或完成。
''';
  }

  /// 构建用户消息
  String _buildUserMessage(String memoryContext) {
    final buffer = StringBuffer();

    buffer.writeln('# 当前任务');
    buffer.writeln(_currentTask);
    buffer.writeln();

    if (memoryContext.isNotEmpty) {
      buffer.writeln(memoryContext);
    }

    if (_history.isNotEmpty) {
      buffer.writeln('## 执行历史');
      for (final h in _history) {
        if (h['type'] == 'tool_call') {
          buffer.writeln('- 调用 ${h['name']}(${h['arguments']})');
        } else if (h['type'] == 'tool_result') {
          final result = h['result'] as String;
          final preview = result.length > 100 ? '${result.substring(0, 100)}...' : result;
          buffer.writeln('  → $preview');
        }
      }
      buffer.writeln();
    }

    if (_observationBuffer.isNotEmpty) {
      buffer.writeln('## 最新观察');
      buffer.writeln(_observationBuffer.toString());
    }

    return buffer.toString();
  }

  /// 获取可用工具
  List<Map<String, dynamic>> _getAvailableTools() {
    final tools = <Map<String, dynamic>>[];

    // ========== 技能工具 ==========
    if (_skillManager != null) {
      for (final skill in _skillManager!.registry.available) {
        // 从 SKILL.md 提取参数定义
        final params = _extractSkillParameters(skill);
        
        tools.add({
          'name': 'skill_${skill.id}',
          'description': skill.metadata.description,
          'parameters': params,
        });
      }
    }

    // ========== 记忆工具 ==========
    tools.addAll([
      {
        'name': 'memory_save',
        'description': '保存重要信息到长期记忆，供以后查询使用',
        'parameters': {
          'type': 'object',
          'properties': {
            'content': {
              'type': 'string',
              'description': '要保存的内容',
            },
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '标签，便于以后检索',
            },
          },
          'required': ['content'],
        },
      },
      {
        'name': 'memory_search',
        'description': '从长期记忆中搜索相关信息',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '搜索关键词',
            },
            'maxResults': {
              'type': 'number',
              'description': '最大返回数量，默认5',
            },
          },
          'required': ['query'],
        },
      },
    ]);

    // ========== 远程工具（通过 Gateway）==========
    // 这些工具需要 Gateway 连接
    if (_remoteConnection != null && _remoteConnection!.isConnected) {
      tools.addAll([
        {
          'name': 'web_search',
          'description': '搜索互联网信息，返回相关网页链接和摘要',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': '搜索关键词',
              },
              'count': {
                'type': 'number',
                'description': '返回结果数量，默认5，最多10',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'web_fetch',
          'description': '获取网页内容，提取可读文本',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': '网页URL',
              },
              'maxChars': {
                'type': 'number',
                'description': '最大返回字符数，默认5000',
              },
            },
            'required': ['url'],
          },
        },
        {
          'name': 'clawhub_search',
          'description': '从 ClawHub 技能市场搜索技能',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': '搜索关键词',
              },
              'limit': {
                'type': 'number',
                'description': '返回数量，默认10',
              },
            },
            'required': ['query'],
          },
        },
        {
          'name': 'clawhub_install',
          'description': '从 ClawHub 安装技能到本地',
          'parameters': {
            'type': 'object',
            'properties': {
              'slug': {
                'type': 'string',
                'description': '技能标识，如 "weather"',
              },
              'version': {
                'type': 'string',
                'description': '版本号，不填则安装最新版',
              },
            },
            'required': ['slug'],
          },
        },
      ]);
    }

    return tools;
  }

  /// 从技能元数据提取参数定义
  Map<String, dynamic> _extractSkillParameters(Skill skill) {
    // 尝试从 SKILL.md 解析参数
    final content = skill.body;
    
    // 简单解析：查找 {xxx} 格式的参数
    final paramRegex = RegExp(r'\{(\w+)\}');
    final matches = paramRegex.allMatches(content);
    
    final properties = <String, dynamic>{};
    final required = <String>[];
    
    for (final match in matches) {
      final paramName = match.group(1)!;
      properties[paramName] = {
        'type': 'string',
        'description': '$paramName 参数',
      };
      required.add(paramName);
    }
    
    // 如果没有找到参数，添加默认的 query 参数
    if (properties.isEmpty) {
      properties['query'] = {
        'type': 'string',
        'description': '输入参数',
      };
    }
    
    return {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  /// 解析工具调用
  List<Map<String, dynamic>> _parseToolCalls(String response) {
    final calls = <Map<String, dynamic>>[];

    // 匹配 ```tool ... ``` 格式
    final toolRegex = RegExp(r'```tool\s*([\s\S]*?)\s*```', multiLine: true);
    for (final match in toolRegex.allMatches(response)) {
      try {
        final jsonStr = match.group(1)!;
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        calls.add(decoded);
      } catch (e) {
        debugPrint('[AgentLoop] 解析工具调用失败: $e');
      }
    }

    return calls;
  }

  /// 执行工具
  Future<String> _executeTool(String name, Map<String, dynamic> arguments) async {
    debugPrint('[AgentLoop] 执行工具: $name');

    try {
      // ========== 技能工具 ==========
      if (name.startsWith('skill_')) {
        final skillId = name.substring(6);
        return await _executeSkill(skillId, arguments);
      }

      // ========== 记忆工具 ==========
      if (name == 'memory_save') {
        return await _saveMemory(arguments);
      }
      if (name == 'memory_search') {
        return await _searchMemory(arguments);
      }

      // ========== 远程工具（需要 Gateway）==========
      if (name == 'web_search') {
        return await _remoteWebSearch(arguments);
      }
      if (name == 'web_fetch') {
        return await _remoteWebFetch(arguments);
      }
      if (name == 'clawhub_search') {
        return await _remoteClawHubSearch(arguments);
      }
      if (name == 'clawhub_install') {
        return await _remoteClawHubInstall(arguments);
      }

      return '错误：未知工具 $name';
    } catch (e) {
      return '错误：$e';
    }
  }

  /// 远程网页搜索
  Future<String> _remoteWebSearch(Map<String, dynamic> arguments) async {
    if (_remoteConnection == null || !_remoteConnection!.isConnected) {
      return '错误：未连接到 Gateway，无法使用网页搜索';
    }

    final query = arguments['query'] as String?;
    if (query == null) return '错误：未提供搜索关键词';
    
    final count = arguments['count'] as int? ?? 5;
    
    return await _remoteConnection!.remoteWebSearch(query, count: count);
  }

  /// 远程获取网页
  Future<String> _remoteWebFetch(Map<String, dynamic> arguments) async {
    if (_remoteConnection == null || !_remoteConnection!.isConnected) {
      return '错误：未连接到 Gateway，无法获取网页';
    }

    final url = arguments['url'] as String?;
    if (url == null) return '错误：未提供网页URL';
    
    final maxChars = arguments['maxChars'] as int? ?? 5000;
    
    return await _remoteConnection!.remoteWebFetch(url, maxChars: maxChars);
  }

  /// 远程 ClawHub 搜索
  Future<String> _remoteClawHubSearch(Map<String, dynamic> arguments) async {
    if (_remoteConnection == null || !_remoteConnection!.isConnected) {
      return '错误：未连接到 Gateway，无法访问 ClawHub';
    }

    final query = arguments['query'] as String?;
    if (query == null) return '错误：未提供搜索关键词';
    
    final limit = arguments['limit'] as int? ?? 10;
    
    // 通过 Gateway 执行 clawhub 命令
    final result = await _remoteConnection!.remoteExec(
      'clawhub',
      args: ['search', query, '--limit', limit.toString()],
    );
    
    return result;
  }

  /// 远程 ClawHub 安装
  Future<String> _remoteClawHubInstall(Map<String, dynamic> arguments) async {
    if (_remoteConnection == null || !_remoteConnection!.isConnected) {
      return '错误：未连接到 Gateway，无法安装技能';
    }

    final slug = arguments['slug'] as String?;
    if (slug == null) return '错误：未提供技能标识';
    
    final version = arguments['version'] as String?;
    
    final args = ['install', slug];
    if (version != null) {
      args.addAll(['--version', version]);
    }
    
    final result = await _remoteConnection!.remoteExec(
      'clawhub',
      args: args,
    );
    
    return result;
  }

  /// 执行技能
  Future<String> _executeSkill(String skillId, Map<String, dynamic> arguments) async {
    if (_skillManager == null) {
      return '错误：Skill 管理器未初始化';
    }

    final skill = _skillManager!.registry.get(skillId);
    if (skill == null) {
      return '错误：未找到技能 $skillId';
    }

    return await _skillManager!.executeSkill(skill, arguments);
  }

  /// 保存记忆
  Future<String> _saveMemory(Map<String, dynamic> arguments) async {
    if (_memoryService == null) {
      return '错误：Memory 服务未初始化';
    }

    final content = arguments['content'] as String?;
    if (content == null) {
      return '错误：未提供内容';
    }

    final tags = (arguments['tags'] as List?)?.map((e) => e.toString()).toList();

    await _memoryService!.add(content, tags: tags);
    return '已保存到记忆';
  }

  /// 搜索记忆
  Future<String> _searchMemory(Map<String, dynamic> arguments) async {
    if (_memoryService == null) {
      return '错误：Memory 服务未初始化';
    }

    final query = arguments['query'] as String?;
    if (query == null) {
      return '错误：未提供搜索关键词';
    }

    final results = _memoryService!.search(query, maxResults: 5);
    if (results.isEmpty) {
      return '未找到相关记忆';
    }

    final buffer = StringBuffer();
    for (final r in results) {
      buffer.writeln('- ${r.entry.content} (相关度: ${r.score.toStringAsFixed(2)})');
    }
    return buffer.toString();
  }

  /// 吜索记忆 (简化版)
  List<MemorySearchResult> search(String query, {int maxResults = 5}) {
    if (_memoryService == null) return [];
    return _memoryService!.search(query, maxResults: maxResults);
  }

  /// 停止执行
  void stop() {
    _state = AgentState.idle;
    _currentTask = '';
    _toolCallHistory.clear();
    _lastLoopWarning = null;
    notifyListeners();
  }
}

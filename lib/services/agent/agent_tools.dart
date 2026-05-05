// 内置 Agent 工具集
//
// 学习 ApkClaw 的 Tool Registry 模式
// 每个工具实现 AgentTool 接口

import 'package:flutter/foundation.dart';
import 'agent_loop_v2.dart';
import '../skills/skill_system.dart';
import '../memory/memory_service.dart';

// ==================== Skill 工具 ====================

/// Skill 执行工具 - 将 Skill 系统包装为 Agent Tool
class SkillAgentTool extends AgentTool {
  final Skill skill;
  final SkillManager skillManager;

  SkillAgentTool(this.skill, this.skillManager);

  @override
  String get name => 'skill_${skill.id}';

  @override
  String get description => skill.metadata.description;

  @override
  Map<String, dynamic> get parametersSchema {
    final params = SkillRegistry.extractParamPlaceholders(skill);
    final properties = <String, dynamic>{};

    for (final entry in params.entries) {
      properties[entry.key] = {
        'type': 'string',
        'description': entry.value,
      };
    }

    // 如果没有参数，添加 query 参数
    if (properties.isEmpty) {
      properties['query'] = {
        'type': 'string',
        'description': '输入内容',
      };
    }

    return {
      'type': 'object',
      'properties': properties,
    };
  }

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      final result = await skillManager.executeSkill(skill, arguments);
      return AgentToolResult.success(result);
    } catch (e) {
      return AgentToolResult.fail('Skill 执行失败: $e');
    }
  }
}

// ==================== 记忆工具 ====================

class MemorySaveTool extends AgentTool {
  final MemoryService memoryService;

  MemorySaveTool(this.memoryService);

  @override
  String get name => 'memory_save';

  @override
  String get description => '保存重要信息到长期记忆，供以后查询';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'content': {
        'type': 'string',
        'description': '要保存的内容',
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '标签列表',
      },
    },
    'required': ['content'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final content = arguments['content'] as String?;
    if (content == null) return AgentToolResult.fail('缺少 content 参数');

    final tags = (arguments['tags'] as List?)?.cast<String>();
    await memoryService.add(content, tags: tags);
    return AgentToolResult.success('已保存到记忆');
  }
}

class MemorySearchTool extends AgentTool {
  final MemoryService memoryService;

  MemorySearchTool(this.memoryService);

  @override
  String get name => 'memory_search';

  @override
  String get description => '从长期记忆中搜索相关信息';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': '搜索关键词',
      },
      'maxResults': {
        'type': 'integer',
        'description': '最大返回数量，默认5',
      },
    },
    'required': ['query'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null) return AgentToolResult.fail('缺少 query 参数');

    final maxResults = arguments['maxResults'] as int? ?? 5;
    final results = memoryService.search(query, maxResults: maxResults);

    if (results.isEmpty) {
      return AgentToolResult.success('未找到相关记忆');
    }

    final buffer = StringBuffer();
    for (final r in results) {
      buffer.writeln('- ${r.entry.content}');
    }
    return AgentToolResult.success(buffer.toString());
  }
}

// ==================== Finish 工具 ====================

class FinishTool extends AgentTool {
  @override
  String get name => 'finish';

  @override
  String get description => '完成任务并返回最终结果';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'summary': {
        'type': 'string',
        'description': '任务完成摘要',
      },
    },
    'required': ['summary'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final summary = arguments['summary'] as String? ?? '任务完成';
    return AgentToolResult.success(summary);
  }
}

// ==================== 时间工具 ====================

class CurrentTimeTool extends AgentTool {
  @override
  String get name => 'get_current_time';

  @override
  String get description => '获取当前日期和时间';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final result = '当前时间: ${now.year}年${now.month}月${now.day}日 '
        '星期${weekdays[now.weekday - 1]} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    return AgentToolResult.success(result);
  }
}

// ==================== 计算器工具 ====================

class CalculatorTool extends AgentTool {
  @override
  String get name => 'calculator';

  @override
  String get description => '计算数学表达式。支持加减乘除、幂运算、括号等。适用于数学计算、单位换算等场景。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'expression': {
        'type': 'string',
        'description': '数学表达式，如 "2+3*4"、"100/3"、"2^10"',
      },
    },
    'required': ['expression'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'] as String?;
    if (expression == null || expression.trim().isEmpty) {
      return AgentToolResult.fail('缺少数学表达式');
    }

    try {
      final result = _evaluate(expression.trim());
      return AgentToolResult.success('$expression = $result');
    } catch (e) {
      return AgentToolResult.fail('计算失败: $e');
    }
  }

  /// 安全的数学表达式求值
  /// 支持数字、+、-、*、/、^、()、π、e
  dynamic _evaluate(String expr) {
    // 预处理
    expr = expr.replaceAll('×', '*');
    expr = expr.replaceAll('÷', '/');
    expr = expr.replaceAll('π', '${3.141592653589793}');
    expr = expr.replaceAll('π', '${3.141592653589793}');
    expr = expr.replaceAll('e+', 'e_pos_'); // 防止把科学计数法里的e替换
    expr = expr.replaceAll(RegExp(r'(?<![0-9])e(?![0-9])'), '${2.718281828459045}');
    expr = expr.replaceAll('e_pos_', 'e+');
    expr = expr.replaceAll('^', '**');

    // 只允许安全字符
    final safe = RegExp(r'^[\d\s\+\-\*\/\.\(\)\,e]+$');
    if (!safe.hasMatch(expr.replaceAll('**', '^'))) {
      throw FormatException('表达式包含不安全字符');
    }

    // 使用 dart 的 math 表达式求值（简单递归下降解析器）
    return _Parser(expr).parse();
  }
}

/// 简单数学表达式解析器（递归下降）
class _Parser {
  final String _input;
  int _pos = 0;

  _Parser(this._input);

  dynamic parse() {
    final result = _expression();
    _skipWhitespace();
    if (_pos < _input.length) {
      throw FormatException('意外的字符: ${_input[_pos]}');
    }
    return result;
  }

  void _skipWhitespace() {
    while (_pos < _input.length && _input[_pos] == ' ') _pos++;
  }

  dynamic _expression() {
    dynamic result = _term();
    while (true) {
      _skipWhitespace();
      if (_pos < _input.length && (_input[_pos] == '+' || _input[_pos] == '-')) {
        final op = _input[_pos];
        _pos++;
        final right = _term();
        if (op == '+') {
          result = (result as num) + (right as num);
        } else {
          result = (result as num) - (right as num);
        }
      } else {
        break;
      }
    }
    return result;
  }

  dynamic _term() {
    dynamic result = _power();
    while (true) {
      _skipWhitespace();
      if (_pos < _input.length && (_input[_pos] == '*' || _input[_pos] == '/')) {
        final op = _input[_pos];
        _pos++;
        final right = _power();
        if (op == '*') {
          result = (result as num) * (right as num);
        } else {
          result = (result as num) / (right as num);
        }
      } else {
        break;
      }
    }
    return result;
  }

  dynamic _power() {
    dynamic result = _unary();
    _skipWhitespace();
    if (_pos < _input.length && _input[_pos] == '*' && _pos + 1 < _input.length && _input[_pos + 1] == '*') {
      _pos += 2;
      final right = _unary();
      result = _pow(result as num, right as num);
    }
    return result;
  }

  dynamic _unary() {
    _skipWhitespace();
    if (_pos < _input.length && _input[_pos] == '-') {
      _pos++;
      return -( _primary() as num);
    }
    if (_pos < _input.length && _input[_pos] == '+') {
      _pos++;
      return _primary();
    }
    return _primary();
  }

  dynamic _primary() {
    _skipWhitespace();
    if (_pos < _input.length && _input[_pos] == '(') {
      _pos++;
      final result = _expression();
      _skipWhitespace();
      if (_pos < _input.length && _input[_pos] == ')') {
        _pos++;
      }
      return result;
    }
    return _number();
  }

  dynamic _number() {
    _skipWhitespace();
    final start = _pos;
    while (_pos < _input.length && (_input[_pos].contains(RegExp(r'[\d\.e\+\-]')))) {
      _pos++;
    }
    if (_pos == start) throw FormatException('期望数字');
    return num.parse(_input.substring(start, _pos));
  }

  num _pow(num base, num exponent) {
    if (exponent == exponent.toInt()) {
      var result = 1;
      for (var i = 0; i < exponent.toInt(); i++) {
        result *= base.toInt();
      }
      return result;
    }
    return base.toDouble() * exponent.toDouble(); // 近似
  }
}

// ==================== 协商工具 ====================

/// 向用户请求帮助 — 当 Agent 遇到无法独立解决的问题时
/// Agent 应该分析问题、提出方案选项，让用户选择
class AskUserTool extends AgentTool {
  @override
  String get name => 'ask_user';

  @override
  String get description =>
      '当你遇到无法独立解决的问题时，向用户说明情况并请求帮助。'
      '你应该：1) 说明遇到的问题 2) 分析可能的原因 3) 提出几个解决方案供用户选择 4) 说明你需要用户提供什么信息。'
      '这不是放弃——是和用户协作解决问题。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'problem': {
        'type': 'string',
        'description': '遇到的问题描述',
      },
      'analysis': {
        'type': 'string',
        'description': '问题原因分析',
      },
      'options': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '建议的解决方案列表',
      },
      'needed_info': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '需要用户提供的信息',
      },
    },
    'required': ['problem', 'options'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final problem = arguments['problem'] as String? ?? '未知问题';
    final analysis = arguments['analysis'] as String?;
    final options = (arguments['options'] as List?)?.cast<String>() ?? [];
    final neededInfo = (arguments['needed_info'] as List?)?.cast<String>() ?? [];

    final buffer = StringBuffer();
    buffer.writeln('🤔 我遇到了一个问题：$problem');
    if (analysis != null && analysis.isNotEmpty) {
      buffer.writeln('\n💡 分析：$analysis');
    }
    if (options.isNotEmpty) {
      buffer.writeln('\n📋 建议方案：');
      for (int i = 0; i < options.length; i++) {
        buffer.writeln('  ${i + 1}. ${options[i]}');
      }
    }
    if (neededInfo.isNotEmpty) {
      buffer.writeln('\n🙋 需要你提供：');
      for (final info in neededInfo) {
        buffer.writeln('  - $info');
      }
    }
    buffer.writeln('\n请回复你的选择或补充信息，我会继续执行。');

    return AgentToolResult.success(buffer.toString());
  }
}

// ==================== 保存为 Skill 工具 ====================

/// 从成功的任务执行路径中自动生成新 Skill
class SaveAsSkillTool extends AgentTool {
  final SkillManager _skillManager;

  SaveAsSkillTool(this._skillManager);

  @override
  String get name => 'save_as_skill';

  @override
  String get description =>
      '当你成功完成一个复杂任务后，把解决路径保存为可复用的 Skill。'
      '下次遇到类似问题时可以直接调用。'
      '请在任务完成后主动调用这个工具，记录成功的解决流程。';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Skill 名称，如 "查火车票"、"compare_prices"',
      },
      'description': {
        'type': 'string',
        'description': 'Skill 的一句话描述',
      },
      'trigger_patterns': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': '触发关键词列表，如 ["火车票", "高铁", "票价"]',
      },
      'steps': {
        'type': 'array',
        'items': {'type': 'object', 'properties': {
          'tool': {'type': 'string', 'description': '调用的工具名'},
          'purpose': {'type': 'string', 'description': '这一步的目的'},
          'params_template': {'type': 'string', 'description': '参数模板，用 {变量名} 表示动态部分'},
        }},
        'description': '解决步骤列表',
      },
      'example_input': {
        'type': 'string',
        'description': '用户原始输入示例',
      },
      'example_output': {
        'type': 'string',
        'description': '最终输出示例（截取前200字）',
      },
    },
    'required': ['name', 'description', 'steps'],
  };

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name'] as String? ?? 'unnamed_skill';
    final description = arguments['description'] as String? ?? '';
    final triggerPatterns = (arguments['trigger_patterns'] as List?)?.cast<String>() ?? [];
    final steps = (arguments['steps'] as List?) ?? [];
    final exampleInput = arguments['example_input'] as String? ?? '';
    final exampleOutput = arguments['example_output'] as String? ?? '';

    // 生成 SKILL.md 格式的内容
    final skillId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\u4e00-\u9fff]'), '_');

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: $name');
    buffer.writeln('description: $description');
    if (triggerPatterns.isNotEmpty) {
      buffer.writeln('triggers: ${triggerPatterns.join(", ")}');
    }
    buffer.writeln('auto_generated: true');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# $name');
    buffer.writeln();
    buffer.writeln('$description');
    buffer.writeln();

    if (steps.isNotEmpty) {
      buffer.writeln('## 解决步骤');
      buffer.writeln();
      for (int i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        final tool = step['tool'] ?? 'unknown';
        final purpose = step['purpose'] ?? '';
        final paramsTemplate = step['params_template'] ?? '';
        buffer.writeln('### 步骤 ${i + 1}: $purpose');
        buffer.writeln('- 工具: `$tool`');
        if (paramsTemplate.isNotEmpty) {
          buffer.writeln('- 参数模板: `$paramsTemplate`');
        }
        buffer.writeln();
      }
    }

    if (exampleInput.isNotEmpty) {
      buffer.writeln('## 示例');
      buffer.writeln();
      buffer.writeln('**输入**: $exampleInput');
      buffer.writeln();
      if (exampleOutput.isNotEmpty) {
        final truncated = exampleOutput.length > 200
            ? '${exampleOutput.substring(0, 200)}...'
            : exampleOutput;
        buffer.writeln('**输出**: $truncated');
      }
    }

    // 保存到本地 skill 存储
    try {
      final skillContent = buffer.toString();
      // 通过 SkillManager 保存
      final skillDir = '${_skillManager.skillsPath}/learned';
      await _skillManager.saveLearnedSkill(skillId, skillContent);

      debugPrint('[SaveAsSkill] 已保存 Skill: $skillId');
      return AgentToolResult.success(
        '✅ 已保存为新 Skill: $name ($skillId)\n'
        '下次遇到类似问题时可以直接使用。',
      );
    } catch (e) {
      debugPrint('[SaveAsSkill] 保存失败: $e');
      return AgentToolResult.fail('保存 Skill 失败: $e');
    }
  }
}

// ==================== 工具注册辅助 ====================

/// 从 Skill 系统自动注册所有工具到 Agent Loop
void registerSkillTools(AgentLoopServiceV2 agentLoop, SkillManager skillManager) {
  for (final skill in skillManager.registry.available) {
    if (skill.isSupported()) {
      agentLoop.registerTool(SkillAgentTool(skill, skillManager));
    }
  }
  debugPrint('[AgentTools] 已注册 ${skillManager.registry.available.length} 个 Skill 工具');
}

/// 注册记忆工具
void registerMemoryTools(AgentLoopServiceV2 agentLoop, MemoryService memoryService) {
  agentLoop.registerTool(MemorySaveTool(memoryService));
  agentLoop.registerTool(MemorySearchTool(memoryService));
}

/// 注册基础工具
void registerBaseTools(AgentLoopServiceV2 agentLoop) {
  agentLoop.registerTool(FinishTool());
  agentLoop.registerTool(CurrentTimeTool());
  agentLoop.registerTool(CalculatorTool());
  agentLoop.registerTool(AskUserTool());  // 协商工具
}

/// 注册 Skill 保存工具（需要 SkillManager）
void registerSkillSaveTool(AgentLoopServiceV2 agentLoop, SkillManager skillManager) {
  agentLoop.registerTool(SaveAsSkillTool(skillManager));
}

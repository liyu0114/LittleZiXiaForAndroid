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
}

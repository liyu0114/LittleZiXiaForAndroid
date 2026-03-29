// 任务分解服务 - OpenClaw 风格
//
// 智能分解复杂任务为子任务，理解任务内在逻辑和依赖关系

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';

/// 子任务
class SubTask {
  final String id;
  final String description;
  final List<String> dependencies;
  String status; // pending, running, completed, failed
  String? result;

  SubTask({
    required this.id,
    required this.description,
    this.dependencies = const [],
    this.status = 'pending',
    this.result,
  });

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dependencies: (json['dependencies'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      status: json['status'] as String? ?? 'pending',
      result: json['result'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'dependencies': dependencies,
    'status': status,
    'result': result,
  };
}

/// 任务计划
class TaskPlan {
  final String mainTask;
  final List<SubTask> subtasks;
  final DateTime createdAt;
  String? summary;

  TaskPlan({
    required this.mainTask,
    required this.subtasks,
    required this.createdAt,
    this.summary,
  });

  /// 获取下一个可执行的子任务
  SubTask? getNextExecutable() {
    for (final subtask in subtasks) {
      if (subtask.status != 'pending') continue;

      bool allDepsMet = true;
      for (final depId in subtask.dependencies) {
        final dep = subtasks.where((s) => s.id == depId).firstOrNull;
        if (dep == null || dep.status != 'completed') {
          allDepsMet = false;
          break;
        }
      }

      if (allDepsMet) return subtask;
    }
    return null;
  }

  /// 是否全部完成
  bool get isCompleted => subtasks.every((s) => s.status == 'completed');

  /// 进度
  double get progress {
    if (subtasks.isEmpty) return 0;
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return completed / subtasks.length;
  }

  /// 进度描述
  String get progressText {
    final completed = subtasks.where((s) => s.status == 'completed').length;
    return '$completed/${subtasks.length}';
  }

  /// 标记子任务完成
  void markCompleted(String subtaskId, String result) {
    final subtask = subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'completed';
      subtask.result = result;
    }
  }

  /// 标记子任务失败
  void markFailed(String subtaskId, String error) {
    final subtask = subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'failed';
      subtask.result = error;
    }
  }
}

/// 任务分解服务
class TaskDecomposer extends ChangeNotifier {
  final LLMProvider _llmProvider;

  TaskPlan? _currentPlan;
  bool _isDecomposing = false;

  TaskPlan? get currentPlan => _currentPlan;
  bool get isDecomposing => _isDecomposing;

  TaskDecomposer({required LLMProvider llmProvider}) : _llmProvider = llmProvider;

  /// 分解任务
  Future<TaskPlan?> decompose(String task) async {
    _isDecomposing = true;
    notifyListeners();

    try {
      debugPrint('[TaskDecomposer] 开始分解任务: $task');

      final prompt = _buildPrompt(task);
      final messages = [
        ChatMessage.system(_getSystemPrompt()),
        ChatMessage.user(prompt),
      ];

      final responseBuffer = StringBuffer();
      final stream = _llmProvider.chatStream(messages);

      await for (final event in stream) {
        if (event.error != null) {
          debugPrint('[TaskDecomposer] 错误: ${event.error}');
          return null;
        }
        if (event.done) break;
        if (event.delta != null) {
          responseBuffer.write(event.delta);
        }
      }

      final response = responseBuffer.toString();
      debugPrint('[TaskDecomposer] LLM 响应: $response');

      final plan = _parseResponse(response, task);
      if (plan != null) {
        _currentPlan = plan;
        notifyListeners();
        debugPrint('[TaskDecomposer] 分解完成，${plan.subtasks.length} 个子任务');
      }

      return plan;
    } finally {
      _isDecomposing = false;
      notifyListeners();
    }
  }

  String _getSystemPrompt() {
    return '''你是一个任务规划专家。你的职责是将复杂任务分解为可执行的子任务。

## 分解原则

1. **理解内在逻辑**：不是简单切分，而是理解任务各个环节的连接点和依赖关系
2. **识别依赖关系**：明确哪些步骤必须先完成，哪些可以并行
3. **处理模糊指令**：基于合理假设分解，标记需要确认的环节
4. **适度的粒度**：每个子任务应该是原子性的，但不要过度分解

## 输出格式

请严格按照以下 JSON 格式输出：

```json
{
  "subtasks": [
    {
      "id": "step1",
      "description": "第一步的描述",
      "dependencies": []
    },
    {
      "id": "step2",
      "description": "第二步的描述",
      "dependencies": ["step1"]
    }
  ],
  "summary": "任务分解的简要说明"
}
```

## 注意事项

- id 使用 step1, step2, step3 格式
- dependencies 数组包含必须先完成的步骤 ID
- 第一步通常没有依赖
- 每个子任务描述要具体、可执行''';
  }

  String _buildPrompt(String task) {
    return '''请分析以下任务，并将其分解为子任务：

任务：$task

请考虑：
1. 这个任务的目标是什么？
2. 需要哪些步骤来完成？
3. 步骤之间有什么依赖关系？
4. 是否有模糊的地方需要后续确认？

请返回 JSON 格式的分解结果。''';
  }

  TaskPlan? _parseResponse(String response, String mainTask) {
    try {
      // 提取 JSON
      String jsonStr = response;
      
      // 尝试从代码块中提取
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!;
      }

      // 解析 JSON
      final data = _parseJson(jsonStr);
      if (data == null) {
        debugPrint('[TaskDecomposer] JSON 解析失败');
        return null;
      }

      final subtasksData = data['subtasks'] as List?;
      if (subtasksData == null) {
        debugPrint('[TaskDecomposer] 没有 subtasks 字段');
        return null;
      }

      final subtasks = subtasksData
          .map((s) => SubTask.fromJson(s as Map<String, dynamic>))
          .toList();

      return TaskPlan(
        mainTask: mainTask,
        subtasks: subtasks,
        createdAt: DateTime.now(),
        summary: data['summary'] as String?,
      );
    } catch (e) {
      debugPrint('[TaskDecomposer] 解析异常: $e');
      return null;
    }
  }

  /// 简单的 JSON 解析
  Map<String, dynamic>? _parseJson(String str) {
    try {
      // 简单提取 JSON 对象
      final start = str.indexOf('{');
      final end = str.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;

      final jsonStr = str.substring(start, end + 1);
      
      // 使用 dart:convert 的 json 解析
      // 这里我们手动实现一个简化版本
      return _simpleJsonDecode(jsonStr);
    } catch (e) {
      debugPrint('[TaskDecomposer] JSON 解析失败: $e');
      return null;
    }
  }

  /// 简化的 JSON 解码
  Map<String, dynamic> _simpleJsonDecode(String jsonStr) {
    final result = <String, dynamic>{};
    
    // 这是一个非常简化的实现
    // 实际应用中应该使用 dart:convert 的 json.decode
    
    // 提取 subtasks 数组
    final subtasksMatch = RegExp(r'"subtasks"\s*:\s*\[([\s\S]*?)\]').firstMatch(jsonStr);
    if (subtasksMatch != null) {
      final subtasksStr = subtasksMatch.group(1)!;
      final subtasks = <Map<String, dynamic>>[];
      
      // 提取每个子任务
      final taskMatches = RegExp(r'\{[^{}]*"id"[^{}]*\}').allMatches(subtasksStr);
      for (final match in taskMatches) {
        final taskStr = match.group(0)!;
        final task = <String, dynamic>{};
        
        // 提取 id
        final idMatch = RegExp(r'"id"\s*:\s*"([^"]*)"').firstMatch(taskStr);
        if (idMatch != null) {
          task['id'] = idMatch.group(1);
        }
        
        // 提取 description
        final descMatch = RegExp(r'"description"\s*:\s*"([^"]*)"').firstMatch(taskStr);
        if (descMatch != null) {
          task['description'] = descMatch.group(1);
        }
        
        // 提取 dependencies
        final depsMatch = RegExp(r'"dependencies"\s*:\s*\[([^\]]*)\]').firstMatch(taskStr);
        if (depsMatch != null) {
          final depsStr = depsMatch.group(1)!;
          final deps = RegExp(r'"([^"]*)"').allMatches(depsStr).map((m) => m.group(1)!).toList();
          task['dependencies'] = deps;
        }
        
        if (task.isNotEmpty) {
          subtasks.add(task);
        }
      }
      
      result['subtasks'] = subtasks;
    }
    
    // 提取 summary
    final summaryMatch = RegExp(r'"summary"\s*:\s*"([^"]*)"').firstMatch(jsonStr);
    if (summaryMatch != null) {
      result['summary'] = summaryMatch.group(1);
    }
    
    return result;
  }

  /// 标记子任务完成
  void markCompleted(String subtaskId, String result) {
    if (_currentPlan == null) return;

    final subtask = _currentPlan!.subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'completed';
      subtask.result = result;
      notifyListeners();
    }
  }

  /// 标记子任务失败
  void markFailed(String subtaskId, String error) {
    if (_currentPlan == null) return;

    final subtask = _currentPlan!.subtasks.where((s) => s.id == subtaskId).firstOrNull;
    if (subtask != null) {
      subtask.status = 'failed';
      subtask.result = error;
      notifyListeners();
    }
  }

  /// 清除计划
  void clear() {
    _currentPlan = null;
    notifyListeners();
  }
}

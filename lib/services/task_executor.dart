// 任务分解与执行引擎
//
// 对标 OpenClaw 的 AgentOrchestrator，实现大任务分解能力

import 'package:flutter/foundation.dart';

/// 任务执行状态
enum TaskExecutionStatus {
  pending,      // 待执行
  inProgress,   // 执行中
  completed,    // 已完成
  failed,       // 失败
  cancelled,    // 已取消
}

/// 子任务
class SubTask {
  final String id;
  final String description;
  final String? skillId;      // 需要使用的技能
  final Map<String, dynamic>? params;
  TaskExecutionStatus status;
  String? result;
  String? error;
  
  SubTask({
    required this.id,
    required this.description,
    this.skillId,
    this.params,
    this.status = TaskExecutionStatus.pending,
    this.result,
    this.error,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'skillId': skillId,
    'params': params,
    'status': status.name,
    'result': result,
    'error': error,
  };
}

/// 任务
class ExecutionTask {
  final String id;
  final String title;
  final String description;
  final List<SubTask> subTasks;
  TaskExecutionStatus status;
  double progress;  // 0.0 - 1.0
  String? finalResult;
  
  ExecutionTask({
    required this.id,
    required this.title,
    required this.description,
    required this.subTasks,
    this.status = TaskExecutionStatus.pending,
    this.progress = 0.0,
    this.finalResult,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'subTasks': subTasks.map((t) => t.toJson()).toList(),
    'status': status.name,
    'progress': progress,
    'finalResult': finalResult,
  };
}

/// 任务执行引擎
class TaskExecutor extends ChangeNotifier {
  // LLM 提供者（用于任务分解）
  final Future<String> Function(String prompt)? _llmCallback;
  
  // 技能执行器
  final Future<String?> Function(String skillId, Map<String, dynamic> params)? _skillExecutor;
  
  // 当前任务
  ExecutionTask? _currentTask;
  bool _isExecuting = false;
  
  ExecutionTask? get currentTask => _currentTask;
  bool get isExecuting => _isExecuting;
  
  TaskExecutor({
    Future<String> Function(String prompt)? llmCallback,
    Future<String?> Function(String skillId, Map<String, dynamic> params)? skillExecutor,
  }) : _llmCallback = llmCallback,
       _skillExecutor = skillExecutor;
  
  /// 分解任务
  Future<ExecutionTask> decomposeTask(String userRequest) async {
    debugPrint('[TaskExecutor] 开始分解任务: $userRequest');
    
    if (_llmCallback == null) {
      // 没有 LLM，使用简单规则分解
      return _simpleDecompose(userRequest);
    }
    
    try {
      // 使用 LLM 分解任务
      final prompt = '''你是一个任务分解专家。请将以下用户请求分解为具体的子任务。

用户请求：$userRequest

请按以下格式输出子任务列表（每个子任务一行）：
1. [技能ID] 子任务描述
2. [技能ID] 子任务描述
...

可用技能：
- weather: 查询天气
- translate: 翻译文本
- location: 获取位置
- web_search: 网页搜索
- calculator: 计算器
- reminder: 设置提醒
- joke: 讲笑话

如果没有合适的技能，写 [none]
只输出子任务列表，不要其他解释。''';

      final response = await _llmCallback!(prompt);
      debugPrint('[TaskExecutor] LLM 响应: $response');
      
      // 解析子任务
      final subTasks = <SubTask>[];
      final lines = response.split('\n');
      int taskIndex = 0;
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        // 解析格式: [技能ID] 描述
        final match = RegExp(r'\[(\w+)\]\s*(.+)').firstMatch(trimmed);
        if (match != null) {
          final skillId = match.group(1);
          final description = match.group(2) ?? '';
          
          if (skillId != 'none') {
            subTasks.add(SubTask(
              id: 'task_${++taskIndex}',
              description: description,
              skillId: skillId,
            ));
          }
        }
      }
      
      // 如果没有分解出子任务，创建一个通用任务
      if (subTasks.isEmpty) {
        subTasks.add(SubTask(
          id: 'task_1',
          description: userRequest,
        ));
      }
      
      return ExecutionTask(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}',
        title: userRequest,
        description: userRequest,
        subTasks: subTasks,
      );
    } catch (e) {
      debugPrint('[TaskExecutor] 任务分解失败: $e');
      // 回退到简单分解
      return _simpleDecompose(userRequest);
    }
  }
  
  /// 简单任务分解（无 LLM 时使用）
  ExecutionTask _simpleDecompose(String userRequest) {
    final subTasks = <SubTask>[];
    int taskIndex = 0;
    
    // 检测关键词
    if (userRequest.contains('天气')) {
      final locationMatch = RegExp(r'(\w+)(?:的)?天气').firstMatch(userRequest);
      final location = locationMatch?.group(1) ?? '北京';
      subTasks.add(SubTask(
        id: 'task_${++taskIndex}',
        description: '查询$location的天气',
        skillId: 'weather',
        params: {'location': location},
      ));
    }
    
    if (userRequest.contains('翻译')) {
      final match = RegExp(r'翻译[成到](\w+)[：:]?\s*(.+)').firstMatch(userRequest);
      if (match != null) {
        final targetLang = match.group(1) ?? '英文';
        final text = match.group(2) ?? '';
        subTasks.add(SubTask(
          id: 'task_${++taskIndex}',
          description: '翻译"$text"到$targetLang',
          skillId: 'translate',
          params: {'text': text, 'target_lang': targetLang == '英文' ? 'en' : targetLang},
        ));
      }
    }
    
    if (userRequest.contains('我在哪') || userRequest.contains('我的位置')) {
      subTasks.add(SubTask(
        id: 'task_${++taskIndex}',
        description: '获取当前位置',
        skillId: 'location',
      ));
    }
    
    if (userRequest.contains('搜索') || userRequest.contains('查一下')) {
      final query = userRequest.replaceAll(RegExp('搜索|查一下|帮我'), '').trim();
      if (query.isNotEmpty) {
        subTasks.add(SubTask(
          id: 'task_${++taskIndex}',
          description: '搜索"$query"',
          skillId: 'web_search',
          params: {'query': query},
        ));
      }
    }
    
    // 如果没有匹配任何技能，创建一个通用任务
    if (subTasks.isEmpty) {
      subTasks.add(SubTask(
        id: 'task_1',
        description: userRequest,
      ));
    }
    
    return ExecutionTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: userRequest,
      description: userRequest,
      subTasks: subTasks,
    );
  }
  
  /// 执行任务
  Future<String> executeTask(ExecutionTask task) async {
    debugPrint('[TaskExecutor] 开始执行任务: ${task.title}');
    
    _currentTask = task;
    _isExecuting = true;
    task.status = TaskExecutionStatus.inProgress;
    notifyListeners();
    
    final results = <String>[];
    int completedCount = 0;
    
    for (final subTask in task.subTasks) {
      debugPrint('[TaskExecutor] 执行子任务: ${subTask.description}');
      
      subTask.status = TaskExecutionStatus.inProgress;
      notifyListeners();
      
      try {
        if (subTask.skillId != null && _skillExecutor != null) {
          // 使用技能执行
          final result = await _skillExecutor!(subTask.skillId!, subTask.params ?? {});
          subTask.result = result;
          subTask.status = TaskExecutionStatus.completed;
          results.add('${subTask.description}: $result');
        } else {
          // 没有技能，标记为失败
          subTask.status = TaskExecutionStatus.failed;
          subTask.error = '没有可用的执行器';
        }
      } catch (e) {
        debugPrint('[TaskExecutor] 子任务执行失败: $e');
        subTask.status = TaskExecutionStatus.failed;
        subTask.error = e.toString();
      }
      
      completedCount++;
      task.progress = completedCount / task.subTasks.length;
      notifyListeners();
    }
    
    // 汇总结果
    if (results.isNotEmpty) {
      task.finalResult = results.join('\n\n');
      task.status = TaskExecutionStatus.completed;
    } else {
      task.finalResult = '任务执行失败';
      task.status = TaskExecutionStatus.failed;
    }
    
    _isExecuting = false;
    notifyListeners();
    
    debugPrint('[TaskExecutor] 任务执行完成: ${task.status}');
    return task.finalResult ?? '任务完成';
  }
  
  /// 取消任务
  void cancelTask() {
    if (_currentTask != null) {
      _currentTask!.status = TaskExecutionStatus.cancelled;
      for (final subTask in _currentTask!.subTasks) {
        if (subTask.status == TaskExecutionStatus.pending || subTask.status == TaskExecutionStatus.inProgress) {
          subTask.status = TaskExecutionStatus.cancelled;
        }
      }
      _isExecuting = false;
      notifyListeners();
    }
  }
  
  /// 清空任务
  void clearTask() {
    _currentTask = null;
    _isExecuting = false;
    notifyListeners();
  }
}

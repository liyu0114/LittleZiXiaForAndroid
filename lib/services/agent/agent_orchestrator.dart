// Agent 编排服务
//
// 支持简单模式和计划模式（任务分解）

import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import '../memory/memory_service.dart';
import '../skills/skill_system.dart';
import '../remote/remote_connection.dart';
import 'agent_loop_service.dart';
import 'task_decomposer.dart';

/// 执行模式
enum ExecutionMode {
  simple,   // 直接执行，适合简单任务
  planned,  // 先分解再执行，适合复杂任务
}

/// Agent 编排服务
class AgentOrchestrator extends ChangeNotifier {
  static final AgentOrchestrator _instance = AgentOrchestrator._internal();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._internal();

  // 核心服务
  AgentLoopService? _agentLoop;
  TaskDecomposer? _taskDecomposer;
  MemoryService? _memoryService;
  RemoteConnection? _remoteConnection;

  // 执行状态
  bool _isExecuting = false;
  String? _currentTaskId;
  String _currentStatus = 'idle';
  double _progress = 0;
  String? _progressMessage;
  TaskPlan? _currentPlan;
  final List<String> _logs = [];
  ExecutionMode _defaultMode = ExecutionMode.simple;

  // Getters
  bool get isExecuting => _isExecuting;
  String? get currentTaskId => _currentTaskId;
  String get currentStatus => _currentStatus;
  double get progress => _progress;
  String? get progressMessage => _progressMessage;
  TaskPlan? get currentPlan => _currentPlan;
  List<String> get logs => List.unmodifiable(_logs);
  ExecutionMode get defaultMode => _defaultMode;
  
  /// 设置默认执行模式
  void setDefaultMode(ExecutionMode mode) {
    _defaultMode = mode;
    notifyListeners();
  }

  /// 初始化
  void initialize({
    required LLMProvider llmProvider,
    MemoryService? memoryService,
    SkillManager? skillManager,
    RemoteConnection? remoteConnection,
  }) {
    _memoryService = memoryService;
    _remoteConnection = remoteConnection;

    // 初始化 Agent Loop
    _agentLoop = AgentLoopService();
    _agentLoop!.initialize(
      llmProvider: llmProvider,
      memoryService: memoryService,
      skillManager: skillManager,
      remoteConnection: remoteConnection,
    );
    _agentLoop!.addListener(_onAgentLoopChange);

    // 初始化 Task Decomposer
    _taskDecomposer = TaskDecomposer(llmProvider: llmProvider);

    debugPrint('[AgentOrchestrator] 初始化完成');
  }

  void _onAgentLoopChange() {
    notifyListeners();
  }

  /// 执行任务（主入口）
  Future<String> execute(String task, {ExecutionMode? mode}) async {
    if (_agentLoop == null) {
      return '错误：Agent 未初始化';
    }

    final execMode = mode ?? _defaultMode;
    
    _isExecuting = true;
    _currentTaskId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentStatus = 'running';
    _progress = 0;
    _progressMessage = null;
    _currentPlan = null;
    _logs.clear();
    _addLog('开始执行任务 [$execMode]: $task');
    notifyListeners();

    try {
      String result;
      
      if (execMode == ExecutionMode.planned) {
        // 计划模式：先分解再执行
        result = await _executePlanned(task);
      } else {
        // 简单模式：直接执行
        result = await _executeSimple(task);
      }

      _currentStatus = 'completed';
      _progress = 1.0;
      _progressMessage = result;
      _addLog('任务完成');

      // 保存到记忆
      if (_memoryService != null) {
        final truncated = result.length > 500 ? '${result.substring(0, 500)}...' : result;
        await _memoryService!.add(
          '任务完成: $task\n结果: $truncated',
          tags: ['task', 'completed'],
        );
      }

      return result;
    } catch (e) {
      _currentStatus = 'failed';
      _progressMessage = e.toString();
      _addLog('任务失败: $e');
      return '任务执行失败: $e';
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// 简单模式执行
  Future<String> _executeSimple(String task) async {
    _addLog('简单模式：直接执行');
    _progress = 0.1;
    notifyListeners();

    final result = await _agentLoop!.execute(task);
    
    if (!result.success) {
      throw Exception(result.error ?? '执行失败');
    }
    
    return result.content;
  }

  /// 计划模式执行
  Future<String> _executePlanned(String task) async {
    _addLog('计划模式：分解任务');
    _progress = 0.05;
    notifyListeners();

    // 1. 分解任务
    final plan = await _taskDecomposer!.decompose(task);
    if (plan == null) {
      _addLog('任务分解失败，回退到简单模式');
      return await _executeSimple(task);
    }

    _currentPlan = plan;
    _addLog('分解完成: ${plan.subtasks.length} 个子任务');
    _addLog('摘要: ${plan.summary ?? "无"}');
    notifyListeners();

    // 2. 逐个执行子任务
    final results = <String, String>{};
    
    while (!plan.isCompleted) {
      final nextTask = plan.getNextExecutable();
      if (nextTask == null) {
        // 没有可执行的子任务，可能是循环依赖
        _addLog('警告：没有可执行的子任务，可能是循环依赖');
        break;
      }

      _addLog('执行子任务: ${nextTask.id} - ${nextTask.description}');
      _progress = 0.1 + 0.8 * plan.progress;
      notifyListeners();

      try {
        final result = await _agentLoop!.execute(nextTask.description);
        if (result.success) {
          plan.markCompleted(nextTask.id, result.content);
          results[nextTask.id] = result.content;
          _addLog('子任务完成: ${nextTask.id}');
        } else {
          plan.markFailed(nextTask.id, result.error ?? '执行失败');
          _addLog('子任务失败: ${nextTask.id} - ${result.error}');
        }
      } catch (e) {
        plan.markFailed(nextTask.id, e.toString());
        _addLog('子任务异常: ${nextTask.id} - $e');
      }
    }

    // 3. 汇总结果
    _progress = 0.95;
    notifyListeners();

    final buffer = StringBuffer();
    buffer.writeln('任务: $task');
    buffer.writeln('');
    
    if (plan.summary != null) {
      buffer.writeln('计划摘要: ${plan.summary}');
      buffer.writeln('');
    }
    
    buffer.writeln('=== 执行结果 ===');
    buffer.writeln('进度: ${plan.progressText}');
    buffer.writeln('');
    
    for (final subtask in plan.subtasks) {
      buffer.writeln('【${subtask.status}】${subtask.id}: ${subtask.description}');
      if (subtask.result != null) {
        final truncated = subtask.result!.length > 200 
            ? '${subtask.result!.substring(0, 200)}...' 
            : subtask.result!;
        buffer.writeln('  结果: $truncated');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// 停止执行
  void stop() {
    if (_agentLoop != null) {
      _agentLoop!.stop();
    }
    _isExecuting = false;
    _currentStatus = 'stopped';
    _addLog('任务已停止');
    notifyListeners();
  }

  /// 重置
  void reset() {
    stop();
    _logs.clear();
    _currentTaskId = null;
    _currentStatus = 'idle';
    _progress = 0;
    _progressMessage = null;
    _currentPlan = null;
    if (_taskDecomposer != null) {
      _taskDecomposer!.clear();
    }
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    debugPrint('[AgentOrchestrator] $message');
  }
}

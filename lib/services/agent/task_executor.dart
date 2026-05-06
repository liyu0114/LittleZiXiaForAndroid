// 任务执行器
//
// 基于 TaskPlan 执行子任务，支持串行/并行/失败重试

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../llm/llm_base.dart';
import 'task_decomposer.dart';

/// 执行模式
enum ExecutionMode {
  sequential, // 串行：一个接一个
  parallel,     // 并行：同时执行
  auto,        // 自动：根据依赖关系
}

/// 执行结果
class ExecutionResult {
  final String subtaskId;
  final String status; // completed, failed
  final String? result;
  final String? error;
  final Duration duration;

  ExecutionResult({
    required this.subtaskId,
    required this.status,
    this.result,
    this.error,
    required this.duration,
  });
}

/// 任务执行器
class TaskExecutor {
  final LLMProvider? _llm;
  final ExecutionMode mode;
  
  TaskPlan? _currentPlan;
  bool _isRunning = false;
  final List<ExecutionResult> _results = [];
  
  TaskExecutor({LLMProvider? llm, this.mode = ExecutionMode.auto}) : _llm = llm;

  /// 是否在运行
  bool get isRunning => _isRunning;
  
  /// 当前计划
  TaskPlan? get currentPlan => _currentPlan;
  
  /// 执行结果
  List<ExecutionResult> get results => List.unmodifiable(_results);

  /// 执行任务计划
  Future<TaskPlan> execute(TaskPlan plan) async {
    if (_isRunning) {
      debugPrint('[TaskExecutor] 已在运行中');
      return plan;
    }
    
    _isRunning = true;
    _currentPlan = plan;
    _results.clear();
    
    debugPrint('[TaskExecutor] 开始执行: ${plan.mainTask}');
    
    try {
      switch (mode) {
        case ExecutionMode.sequential:
          await _executeSequential(plan);
          break;
        case ExecutionMode.parallel:
          await _executeParallel(plan);
          break;
        case ExecutionMode.auto:
          await _executeAuto(plan);
          break;
      }
    } catch (e) {
      debugPrint('[TaskExecutor] 执行异常: $e');
    }
    
    _isRunning = false;
    return plan;
  }

  /// 串行执行
  Future<void> _executeSequential(TaskPlan plan) async {
    for (final subtask in plan.subtasks) {
      final result = await _executeSubtask(subtask);
      _results.add(result);
      
      if (result.status == 'failed') {
        debugPrint('[TaskExecutor] 子任务失败，停止');
        break;
      }
    }
  }

  /// 并行执行
  Future<void> _executeParallel(TaskPlan plan) async {
    // 找出没有依赖的子任务
    final readyTasks = plan.subtasks
        .where((s) => s.dependencies.isEmpty)
        .toList();
    
    await Future.wait(readyTasks.map((t) => _executeSubtask(t)));
  }

  /// 自动执行（根据依赖）
  Future<void> _executeAuto(TaskPlan plan) async {
    while (!plan.isCompleted) {
      final next = plan.getNextExecutable();
      if (next == null) break;
      
      final result = await _executeSubtask(next);
      _results.add(result);
      
      if (result.status == 'failed') {
        debugPrint('[TaskExecutor] 执行失败');
        break;
      }
    }
  }

  /// 执行单个子任务
  Future<ExecutionResult> _executeSubtask(SubTask subtask) async {
    final startTime = DateTime.now();
    
    debugPrint('[TaskExecutor] 执行: ${subtask.id} - ${subtask.description}');
    
    // 更新状态
    subtask.status = 'running';
    
    try {
      String? result;
      
      if (_llm != null) {
        // 使用 LLM 执行
        final response = await _llm!.chat([
          {'role': 'user', 'content': subtask.description},
        ]);
        result = response.content;
      } else {
        // 模拟执行
        await Future.delayed(const Duration(milliseconds: 500));
        result = '完成: ${subtask.description}';
      }
      
      subtask.status = 'completed';
      subtask.result = result;
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('[TaskExecutor] 完成: ${subtask.id} (${duration.inMs}ms)');
      
      return ExecutionResult(
        subtaskId: subtask.id,
        status: 'completed',
        result: result,
        duration: duration,
      );
    } catch (e) {
      subtask.status = 'failed';
      subtask.result = e.toString();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('[TaskExecutor] 失败: ${subtask.id} - $e');
      
      return ExecutionResult(
        subtaskId: subtask.id,
        status: 'failed',
        error: e.toString(),
        duration: duration,
      );
    }
  }

  /// 取消执行
  void cancel() {
    if (_currentPlan != null) {
      for (final subtask in _currentPlan!.subtasks) {
        if (subtask.status == 'running') {
          subtask.status = 'pending';
        }
      }
    }
    _isRunning = false;
    debugPrint('[TaskExecutor] 已取消');
  }

  /// 获取执行进度
  double get progress => _currentPlan?.progress ?? 0;
  
  /// 获取进度文本
  String get progressText => _currentPlan?.progressText ?? '0/0';
}
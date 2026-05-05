// 任务调度服务
//
// 任务优先级管理和调度

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 任务优先级
enum TaskPriority {
  low,
  normal,
  high,
  urgent,
}

/// 调度任务
class ScheduledTask {
  final String id;
  final String name;
  final TaskPriority priority;
  final DateTime scheduledAt;
  final Duration? interval;
  bool isRunning;
  
  ScheduledTask({
    required this.id,
    required this.name,
    required this.priority,
    required this.scheduledAt,
    this.interval,
    this.isRunning = false,
  });
}

/// 任务调度器
class TaskScheduler extends ChangeNotifier {
  final List<ScheduledTask> _tasks = [];
  Timer? _timer;
  
  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);
  
  /// 添加定时任务
  void addTask(ScheduledTask task) {
    _tasks.add(task);
    _tasks.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    notifyListeners();
  }
  
  /// 启动调度
  void start() {
    _timer ??= Timer.periodic(Duration(seconds: 1), (_) {
      _checkAndRunTasks();
    });
  }
  
  /// 停止调度
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
  
  void _checkAndRunTasks() {
    final now = DateTime.now();
    for (final task in _tasks) {
      if (!task.isRunning && task.scheduledAt.isBefore(now)) {
        _executeTask(task);
      }
    }
  }
  
  Future<void> _executeTask(ScheduledTask task) async {
    task.isRunning = true;
    notifyListeners();
    
    debugPrint('[TaskScheduler] 执行任务: ${task.name}');
    
    // TODO: 实际执行任务
    
    task.isRunning = false;
    
    // 如果是重复任务，重新安排
    if (task.interval != null) {
      task.scheduledAt = DateTime.now().add(task.interval!);
    }
    
    notifyListeners();
  }
  
  /// 取消任务
  void cancelTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
  
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
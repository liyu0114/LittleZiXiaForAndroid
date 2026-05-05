// 贡献算力服务
//
// GPU/CPU算力贡献

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 算力类型
enum ComputeType {
  gpu,
  cpu,
  hybrid,
}

/// 贡献者
class Contributor {
  final String id;
  final String name;
  final ComputeType type;
  final int score;
  bool isActive;
  
  Contributor({
    required this.id,
    required this.name,
    required this.type,
    this.score = 0,
    this.isActive = false,
  });
}

/// 任务
class ComputeTask {
  final String id;
  final String name;
  final int progress;
  final Map<String, dynamic> params;
  bool isCompleted;
  
  ComputeTask({
    required this.id,
    required this.name,
    this.progress = 0,
    required this.params,
    this.isCompleted = false,
  });
}

/// 贡献算力管理器
class ComputePowerManager extends ChangeNotifier {
  final List<Contributor> _contributors = [];
  final Map<String, ComputeTask> _tasks = {};
  
  /// 注册贡献者
  Future<void> register(String name, ComputeType type) async {
    _contributors.add(Contributor(
      id: 'contrib_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
    ));
    notifyListeners();
  }
  
  /// 激活贡献
  void activate(String contributorId) {
    final index = _contributors.indexWhere((c) => c.id == contributorId);
    if (index != -1) {
      _contributors[index].isActive = true;
      notifyListeners();
    }
  }
  
  /// 停用贡献
  void deactivate(String contributorId) {
    final index = _contributors.indexWhere((c) => c.id == contributorId);
    if (index != -1) {
      _contributors[index].isActive = false;
      notifyListeners();
    }
  }
  
  /// 提交任务
  Future<String> submitTask(String name, Map<String, dynamic> params) async {
    final task = ComputeTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      params: params,
    );
    
    _tasks[task.id] = task;
    notifyListeners();
    
    return task.id;
  }
  
  /// 更新进度
  void updateProgress(String taskId, int progress) {
    final task = _tasks[taskId];
    if (task != null) {
      task.progress = progress;
      notifyListeners();
    }
  }
  
  /// 获取活跃贡献者
  List<Contributor> getActiveContributors() {
    return _contributors.where((c) => c.isActive).toList();
  }
  
  /// 计算积分
  void addScore(String contributorId, int score) {
    final index = _contributors.indexWhere((c) => c.id == contributorId);
    if (index != -1) {
      _contributors[index].score += score;
      notifyListeners();
    }
  }
  
  /// 获取排行榜
  List<Contributor> getLeaderboard() {
    final sorted = List<Contributor>.from(_contributors);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }
}
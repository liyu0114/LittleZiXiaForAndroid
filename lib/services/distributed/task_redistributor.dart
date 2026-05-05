// 分布式任务重分发服务
//
// 节点断开时重新分发任务

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 节点状态
enum NodeStatus {
  active,
  busy,
  offline,
}

/// 计算节点
class ComputeNode {
  final String id;
  final String name;
  NodeStatus status;
  DateTime lastHeartbeat;
  int currentTaskId;
  
  ComputeNode({
    required this.id,
    required this.name,
    this.status = NodeStatus.active,
    this.lastHeartbeat,
    this.currentTaskId = 0,
  });
}

/// 分发任务
class DistributedTask {
  final String id;
  final String name;
  final String nodeId;
  final int progress;
  final DateTime startedAt;
  bool isCompleted;
  bool isFailed;
  
  DistributedTask({
    required this.id,
    required this.name,
    required this.nodeId,
    this.progress = 0,
    required this.startedAt,
    this.isCompleted = false,
    this.isFailed = false,
  });
}

/// 分布式任务重分发器
class TaskRedistributor extends ChangeNotifier {
  final Map<String, ComputeNode> _nodes = {};
  final Map<String, DistributedTask> _tasks = {};
  Timer? _heartbeatTimer;
  
  static const int NODE_TIMEOUT_SECONDS = 60;
  
  /// 注册节点
  void registerNode(String id, String name) {
    _nodes[id] = ComputeNode(
      id: id,
      name: name,
      lastHeartbeat: DateTime.now(),
    );
    notifyListeners();
  }
  
  /// 心跳
  void heartbeat(String nodeId) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.lastHeartbeat = DateTime.now();
      node.status = NodeStatus.active;
    }
  }
  
  /// 节点离线
  void nodeOffline(String nodeId) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.status = NodeStatus.offline;
      
      // 重新分发该节点的任务
      _redistributeTasks(nodeId);
    }
    notifyListeners();
  }
  
  /// 提交任务
  Future<String> submitTask(String taskName, String nodeId) async {
    final task = DistributedTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      name: taskName,
      nodeId: nodeId,
      startedAt: DateTime.now(),
    );
    
    _tasks[task.id] = task;
    notifyListeners();
    
    return task.id;
  }
  
  /// 任务进度更新
  void updateProgress(String taskId, int progress) {
    final task = _tasks[taskId];
    if (task != null) {
      task.progress = progress;
      notifyListeners();
    }
  }
  
  /// 任务完成
  void completeTask(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      task.isCompleted = true;
      task.progress = 100;
      notifyListeners();
    }
  }
  
  /// 获取活跃节点
  List<ComputeNode> getActiveNodes() {
    return _nodes.values
        .where((n) => n.status == NodeStatus.active)
        .toList();
  }
  
  void _redistributeTasks(String offlineNodeId) {
    // 找出离线节点的任务
    final failedTasks = _tasks.values
        .where((t) => t.nodeId == offlineNodeId && !t.isCompleted)
        .toList();
    
    for (final task in failedTasks) {
      // 分配给活跃节点
      final newNode = getActiveNodes().firstOrNull;
      if (newNode != null) {
        task.nodeId = newNode.id;
        task.progress = 0;
        
        debugPrint('[TaskRedistributor] 任务 ${task.id} 重新分发到 ${newNode.id}');
      } else {
        task.isFailed = true;
      }
    }
    
    notifyListeners();
  }
  
  /// 启动心跳检查
  void startHeartbeatCheck() {
    _heartbeatTimer ??= Timer.periodic(Duration(seconds: 10), (_) {
      _checkNodes();
    });
  }
  
  void _checkNodes() {
    final now = DateTime.now();
    
    for (final node in _nodes.values) {
      final diff = now.difference(node.lastHeartbeat).inSeconds;
      if (diff >= NODE_TIMEOUT_SECONDS && node.status != NodeStatus.offline) {
        nodeOffline(node.id);
      }
    }
  }
  
  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
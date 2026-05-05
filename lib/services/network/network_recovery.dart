// 断线重连服务
//
// 处理网络断开/恢复时的消息和任务续接

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 网络状态
enum NetworkStatus {
  connected,
  reconnecting,
  offline,
}

/// 网络监听器
class NetworkMonitor extends ChangeNotifier {
  NetworkStatus _status = NetworkStatus.connected;
  DateTime? _lastConnected;
  DateTime? _lastDisconnected;
  Timer? _heartbeatTimer;
  
  NetworkStatus get status => _status;
  DateTime? get lastConnected => _lastConnected;
  DateTime? get lastDisconnected => _lastDisconnected;
  
  // 模拟网络状态变化（实际应该监听系统网络状态）
  void setStatus(NetworkStatus status) {
    _status = status;
    if (status == NetworkStatus.connected) {
      _lastConnected = DateTime.now();
    } else {
      _lastDisconnected = DateTime.now();
    }
    notifyListeners();
    
    // 触发重连处理
    if (status == NetworkStatus.connected && _lastDisconnected != null) {
      _onReconnected();
    }
  }
  
  void _onReconnected() {
    debugPrint('[NetworkMonitor] 网络重连: ${_lastDisconnected} -> ${_lastConnected}');
    // TODO: 触发消息重发、任务恢复
  }
  
  /// 启动心跳
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      // TODO: 发送心跳检测网络
    });
  }
  
  /// 停止心跳  
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }
  
  @override
  void dispose() {
    stopHeartbeat();
    super.dispose();
  }
}

/// 消息队列 - 离线时缓存消息
class MessageQueue extends ChangeNotifier {
  final List<QueuedMessage> _queue = [];
  
  List<QueuedMessage> get queue => List.unmodifiable(_queue);
  int get length => _queue.length;
  
  /// 添加消息到队列
  void enqueue(QueuedMessage message) {
    _queue.add(message);
    notifyListeners();
  }
  
  /// 获取并移除消息
  List<QueuedMessage> dequeueAll() {
    final messages = List<QueuedMessage>.from(_queue);
    _queue.clear();
    notifyListeners();
    return messages;
  }
  
  /// 清空队列
  void clear() {
    _queue.clear();
    notifyListeners();
  }
}

/// 排队的消息
class QueuedMessage {
  final String id;
  final String content;
  final String targetId;
  final DateTime timestamp;
  final int retryCount;
  
  QueuedMessage({
    required this.id,
    required this.content,
    required this.targetId,
    required this.timestamp,
    this.retryCount = 0,
  });
}

/// 任务恢复管理器
class TaskRecoveryManager extends ChangeNotifier {
  // 正在执行的任务
  final Map<String, TaskRecovery> _runningTasks = {};
  
  /// 开始任务时保存状态
  void saveTaskState(String taskId, Map<String, dynamic> state) {
    _runningTasks[taskId] = TaskRecovery(
      taskId: taskId,
      state: state,
      savedAt: DateTime.now(),
    );
    notifyListeners();
  }
  
  /// 恢复任务
  Future<Map<String, dynamic>?> restoreTask(String taskId) async {
    final task = _runningTasks[taskId];
    if (task != null) {
      _runningTasks.remove(taskId);
      notifyListeners();
      return task.state;
    }
    return null;
  }
  
  /// 获取任务列表
  List<String> getRunningTasks() => _runningTasks.keys.toList();
}

/// 任务恢复信息
class TaskRecovery {
  final String taskId;
  final Map<String, dynamic> state;
  final DateTime savedAt;
  
  TaskRecovery({
    required this.taskId,
    required this.state,
    required this.savedAt,
  });
}
// Agent 生命周期管理
//
// 参考 OpenClaw 的 lifecycle 事件系统

import 'package:flutter/foundation.dart';

/// Agent 生命周期阶段
enum AgentLifecyclePhase {
  start,     // 任务开始
  thinking,  // 正在思考
  acting,    // 正在执行工具
  observing, // 正在观察结果
  end,       // 任务完成
  error,     // 发生错误
}

/// Agent 生命周期事件
class AgentLifecycleEvent {
  final AgentLifecyclePhase phase;
  final String? stepId;
  final String? message;
  final double? progress; // 0.0 - 1.0
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AgentLifecycleEvent({
    required this.phase,
    this.stepId,
    this.message,
    this.progress,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 获取阶段显示名称
  String get phaseDisplayName {
    switch (phase) {
      case AgentLifecyclePhase.start:
        return '开始';
      case AgentLifecyclePhase.thinking:
        return '思考中';
      case AgentLifecyclePhase.acting:
        return '执行中';
      case AgentLifecyclePhase.observing:
        return '观察中';
      case AgentLifecyclePhase.end:
        return '完成';
      case AgentLifecyclePhase.error:
        return '错误';
    }
  }

  /// 获取阶段图标
  String get phaseIcon {
    switch (phase) {
      case AgentLifecyclePhase.start:
        return '🚀';
      case AgentLifecyclePhase.thinking:
        return '🤔';
      case AgentLifecyclePhase.acting:
        return '⚡';
      case AgentLifecyclePhase.observing:
        return '👀';
      case AgentLifecyclePhase.end:
        return '✅';
      case AgentLifecyclePhase.error:
        return '❌';
    }
  }

  /// 格式化为显示文本
  String toDisplayText() {
    final buffer = StringBuffer();
    buffer.write('$phaseIcon $phaseDisplayName');
    
    if (message != null) {
      buffer.write(': $message');
    }
    
    if (progress != null) {
      buffer.write(' (${(progress! * 100).toStringAsFixed(0)}%)');
    }
    
    return buffer.toString();
  }

  @override
  String toString() {
    return 'AgentLifecycleEvent(phase: $phase, message: $message, progress: $progress)';
  }
}

/// 生命周期监听器
typedef LifecycleListener = void Function(AgentLifecycleEvent event);

/// 生命周期管理器
class AgentLifecycleManager extends ChangeNotifier {
  final List<AgentLifecycleEvent> _events = [];
  final List<LifecycleListener> _listeners = [];
  AgentLifecyclePhase _currentPhase = AgentLifecyclePhase.start;

  List<AgentLifecycleEvent> get events => List.unmodifiable(_events);
  AgentLifecyclePhase get currentPhase => _currentPhase;
  
  /// 获取最新事件
  AgentLifecycleEvent? get lastEvent => 
      _events.isNotEmpty ? _events.last : null;

  /// 添加监听器
  void addListener(LifecycleListener listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(LifecycleListener listener) {
    _listeners.remove(listener);
  }

  /// 发送事件
  void emit(AgentLifecycleEvent event) {
    _currentPhase = event.phase;
    _events.add(event);
    
    // 通知所有监听器
    for (final listener in _listeners) {
      listener(event);
    }
    
    // 通知 ChangeNotifier 监听器
    notifyListeners();
    
    debugPrint('[AgentLifecycle] ${event.toDisplayText()}');
  }

  /// 便捷方法：发送开始事件
  void emitStart(String message, {double? progress}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.start,
      message: message,
      progress: progress ?? 0,
    ));
  }

  /// 便捷方法：发送思考事件
  void emitThinking(String message, {double? progress}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.thinking,
      message: message,
      progress: progress,
    ));
  }

  /// 便捷方法：发送执行事件
  void emitActing(String message, {String? stepId, double? progress}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.acting,
      stepId: stepId,
      message: message,
      progress: progress,
    ));
  }

  /// 便捷方法：发送观察事件
  void emitObserving(String message, {double? progress}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.observing,
      message: message,
      progress: progress,
    ));
  }

  /// 便捷方法：发送完成事件
  void emitEnd(String message, {double? progress}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.end,
      message: message,
      progress: progress ?? 1.0,
    ));
  }

  /// 便捷方法：发送错误事件
  void emitError(String message, {Object? error, StackTrace? stackTrace}) {
    emit(AgentLifecycleEvent(
      phase: AgentLifecyclePhase.error,
      message: message,
      metadata: {
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
      },
    ));
  }

  /// 清除所有事件
  void clear() {
    _events.clear();
    _currentPhase = AgentLifecyclePhase.start;
    notifyListeners();
  }

  /// 获取事件历史摘要
  String getSummary() {
    if (_events.isEmpty) return '无事件';
    
    final buffer = StringBuffer();
    for (final event in _events) {
      buffer.writeln(event.toDisplayText());
    }
    return buffer.toString();
  }
}

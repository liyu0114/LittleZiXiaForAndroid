// Agent 进度报告器
//
// 支持流式进度回调

import 'package:flutter/foundation.dart';
import 'lifecycle.dart';

/// 进度回调类型
typedef ProgressCallback = void Function(AgentLifecycleEvent event);

/// 进度报告器
///
/// 负责在 Agent 执行过程中发送进度更新
class ProgressReporter {
  final ProgressCallback? onProgress;
  final AgentLifecycleManager? lifecycleManager;
  
  int _totalSteps = 0;
  int _currentStep = 0;
  String _currentTask = '';

  ProgressReporter({
    this.onProgress,
    this.lifecycleManager,
  });

  /// 设置总步骤数
  void setTotalSteps(int steps) {
    _totalSteps = steps;
    _currentStep = 0;
  }

  /// 开始新步骤
  void startStep(String task) {
    _currentTask = task;
    _currentStep++;
    
    final progress = _totalSteps > 0 
        ? _currentStep / _totalSteps 
        : 0.1 * _currentStep;
    
    _reportProgress(
      AgentLifecyclePhase.acting,
      task,
      progress.clamp(0.0, 1.0),
    );
  }

  /// 报告思考中
  void reportThinking(String message) {
    _reportProgress(
      AgentLifecyclePhase.thinking,
      message,
      null,
    );
  }

  /// 报告执行中
  void reportActing(String message, {String? stepId}) {
    _reportProgress(
      AgentLifecyclePhase.acting,
      message,
      null,
      stepId: stepId,
    );
  }

  /// 报告观察中
  void reportObserving(String message) {
    _reportProgress(
      AgentLifecyclePhase.observing,
      message,
      null,
    );
  }

  /// 报告完成
  void reportComplete(String message) {
    _reportProgress(
      AgentLifecyclePhase.end,
      message,
      1.0,
    );
  }

  /// 报告错误
  void reportError(String message, {Object? error}) {
    _reportProgress(
      AgentLifecyclePhase.error,
      message,
      null,
      metadata: {'error': error?.toString()},
    );
  }

  /// 内部报告方法
  void _reportProgress(
    AgentLifecyclePhase phase,
    String message,
    double? progress, {
    String? stepId,
    Map<String, dynamic>? metadata,
  }) {
    final event = AgentLifecycleEvent(
      phase: phase,
      message: message,
      progress: progress,
      stepId: stepId,
      metadata: metadata,
    );

    // 调用回调
    onProgress?.call(event);

    // 发送到生命周期管理器
    lifecycleManager?.emit(event);

    debugPrint('[ProgressReporter] ${event.toDisplayText()}');
  }

  /// 获取当前进度
  double get currentProgress {
    if (_totalSteps == 0) return 0;
    return _currentStep / _totalSteps;
  }

  /// 获取当前任务
  String get currentTask => _currentTask;

  /// 重置
  void reset() {
    _totalSteps = 0;
    _currentStep = 0;
    _currentTask = '';
  }
}

/// 进度报告混入
///
/// 为 Agent 服务提供进度报告能力
mixin ProgressReporting {
  ProgressReporter? _progressReporter;

  /// 初始化进度报告器
  void initProgressReporter({
    ProgressCallback? onProgress,
    AgentLifecycleManager? lifecycleManager,
  }) {
    _progressReporter = ProgressReporter(
      onProgress: onProgress,
      lifecycleManager: lifecycleManager,
    );
  }

  /// 获取进度报告器
  ProgressReporter get progressReporter {
    _progressReporter ??= ProgressReporter();
    return _progressReporter!;
  }

  /// 报告进度
  void reportProgress(AgentLifecyclePhase phase, String message, {double? progress}) {
    final event = AgentLifecycleEvent(
      phase: phase,
      message: message,
      progress: progress,
    );
    _progressReporter?.onProgress?.call(event);
    _progressReporter?.lifecycleManager?.emit(event);
  }
}

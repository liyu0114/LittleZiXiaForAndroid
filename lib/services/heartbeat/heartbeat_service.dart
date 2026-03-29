// Heartbeat 系统
//
// 定期检查和主动提醒

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Heartbeat 服务
class HeartbeatService extends ChangeNotifier {
  Timer? _timer;
  bool _isActive = false;
  DateTime? _lastCheck;
  Duration _interval = Duration(minutes: 30);

  // 检查状态
  Map<String, DateTime> _lastChecks = {};

  bool get isActive => _isActive;
  DateTime? get lastCheck => _lastCheck;
  Duration get interval => _interval;
  Map<String, DateTime> get lastChecks => _lastChecks;

  /// 启动 Heartbeat
  void start({Duration? interval}) {
    if (_isActive) return;

    _interval = interval ?? _interval;
    _isActive = true;

    _timer = Timer.periodic(_interval, (timer) {
      _performCheck();
    });

    debugPrint('[Heartbeat] 已启动，间隔: ${_interval.inMinutes} 分钟');
    notifyListeners();
  }

  /// 停止 Heartbeat
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    debugPrint('[Heartbeat] 已停止');
    notifyListeners();
  }

  /// 执行检查
  Future<void> _performCheck() async {
    _lastCheck = DateTime.now();
    debugPrint('[Heartbeat] 执行检查: $_lastCheck');

    // 通知监听者
    notifyListeners();
  }

  /// 手动触发检查
  Future<void> triggerCheck() async {
    await _performCheck();
  }

  /// 更新检查状态
  void updateCheck(String checkType) {
    _lastChecks[checkType] = DateTime.now();
    notifyListeners();
  }

  /// 检查是否需要执行某个检查
  bool shouldCheck(String checkType, {Duration? minInterval}) {
    final lastTime = _lastChecks[checkType];
    if (lastTime == null) return true;

    final interval = minInterval ?? Duration(hours: 2);
    return DateTime.now().difference(lastTime) > interval;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Heartbeat 检查项
class HeartbeatCheck {
  final String id;
  final String name;
  final Future<String> Function() check;
  final Duration minInterval;

  HeartbeatCheck({
    required this.id,
    required this.name,
    required this.check,
    this.minInterval = const Duration(hours: 2),
  });
}

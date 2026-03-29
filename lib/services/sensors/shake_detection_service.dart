// 摇晃检测服务
//
// 通过加速度计检测摇晃动作

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

/// 摇晃检测服务
class ShakeDetectionService extends ChangeNotifier {
  StreamSubscription? _subscription;
  DateTime? _lastShakeTime;
  int _shakeCount = 0;
  double _lastAcceleration = 0;

  bool _isMonitoring = false;
  double _threshold = 15.0; // 摇晃阈值

  bool get isMonitoring => _isMonitoring;
  int get shakeCount => _shakeCount;
  DateTime? get lastShakeTime => _lastShakeTime;

  /// 开始监听
  void startMonitoring({double threshold = 15.0}) {
    if (_isMonitoring) return;

    _threshold = threshold;
    _isMonitoring = true;
    _shakeCount = 0;

    _subscription = userAccelerometerEventStream().listen((event) {
      // 计算加速度大小
      final acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      );

      // 检测摇晃（加速度超过阈值）
      if (acceleration > _threshold) {
        final now = DateTime.now();
        
        // 防抖：500ms 内只算一次
        if (_lastShakeTime == null || 
            now.difference(_lastShakeTime!).inMilliseconds > 500) {
          _lastShakeTime = now;
          _shakeCount++;
          notifyListeners();
          debugPrint('[Shake] 检测到摇晃！次数: $_shakeCount, 加速度: $acceleration');
        }
      }

      _lastAcceleration = acceleration;
    });

    debugPrint('[Shake] 开始监听摇晃');
  }

  /// 停止监听
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _isMonitoring = false;
    debugPrint('[Shake] 停止监听摇晃');
  }

  /// 重置计数
  void resetCount() {
    _shakeCount = 0;
    _lastShakeTime = null;
    notifyListeners();
  }

  /// 检测单次摇晃
  Future<bool> detectShake({Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<bool>();
    StreamSubscription? sub;

    sub = userAccelerometerEventStream().listen((event) {
      final acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      );

      if (acceleration > _threshold) {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    // 超时
    Future.delayed(timeout, () {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// 获取摇晃信息
  String getShakeInfo() {
    if (!_isMonitoring) {
      return '⚠️ 未开始监听摇晃';
    }

    return '''👆 摇晃检测

状态: 监听中
摇晃次数: $_shakeCount
阈值: $_threshold m/s²
${_lastShakeTime != null ? '最后摇晃: ${_lastShakeTime!.toString().substring(11, 19)}' : ''}''';
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

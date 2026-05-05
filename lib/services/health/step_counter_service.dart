// 步数计数服务
//
// 查看今天的步数

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

/// 步数服务
class StepCounterService extends ChangeNotifier {
  Stream<StepCount>? _stepCountStream;
  int _steps = 0;
  DateTime? _lastUpdate;

  int get steps => _steps;
  DateTime? get lastUpdate => _lastUpdate;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 检查权限
      // Note: Android 需要活动识别权限

      // 监听步数
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        _steps = event.steps;
        _lastUpdate = DateTime.now();
        notifyListeners();
        debugPrint('[StepCounter] 步数更新: $_steps');
      });

      debugPrint('[StepCounter] 初始化完成');
    } catch (e) {
      debugPrint('[StepCounter] 初始化失败: $e');
    }
  }

  /// 获取步数信息
  String getStepInfo() {
    // 计算距离（估算：每步约 0.7 米）
    final distance = (_steps * 0.7).toStringAsFixed(0);

    // 计算卡路里（估算：每步约 0.04 卡路里）
    final calories = (_steps * 0.04).toStringAsFixed(0);

    // 评价
    String evaluation;
    if (_steps < 3000) {
      evaluation = '💪 继续加油！';
    } else if (_steps < 6000) {
      evaluation = '👍 不错！';
    } else if (_steps < 10000) {
      evaluation = '🌟 很棒！';
    } else {
      evaluation = '🏆 太厉害了！';
    }

    return '''🏃 今天运动数据

步数: $_steps 步
距离: $distance 米（估算）
消耗: $calories 卡路里（估算）

$evaluation''';
  }

  /// 获取步数等级
  String getStepLevel() {
    if (_steps < 3000) return '久坐';
    if (_steps < 6000) return '轻度活动';
    if (_steps < 10000) return '中度活动';
    if (_steps < 15000) return '高度活动';
    return '运动达人';
  }

  @override
  void dispose() {
    _stepCountStream = null;
    super.dispose();
  }
}

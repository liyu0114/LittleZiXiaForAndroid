// 指南针服务
//
// 查看当前朝向

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// 指南针服务
class CompassService extends ChangeNotifier {
  CompassEvent? _lastHeading;

  CompassEvent? get lastHeading => _lastHeading;
  double? get heading => _lastHeading?.heading;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 监听方向变化
      FlutterCompass.events?.listen((CompassEvent event) {
        _lastHeading = event;
        notifyListeners();
      });

      debugPrint('[Compass] 初始化完成');
    } catch (e) {
      debugPrint('[Compass] 初始化失败: $e');
    }
  }

  /// 获取方向描述
  String getDirection(double degrees) {
    // 标准化到 0-360
    final normalized = degrees < 0 ? degrees + 360 : degrees;

    if (normalized < 22.5 || normalized >= 337.5) return '北';
    if (normalized < 67.5) return '东北';
    if (normalized < 112.5) return '东';
    if (normalized < 157.5) return '东南';
    if (normalized < 202.5) return '南';
    if (normalized < 247.5) return '西南';
    if (normalized < 292.5) return '西';
    return '西北';
  }

  /// 获取提示
  String getTip(double degrees) {
    // 根据朝向给出建议
    final normalized = degrees < 0 ? degrees + 360 : degrees;
    
    if (normalized > 45 && normalized < 225) {
      return '提示: 当前朝向阳面，注意防晒';
    }
    return '';
  }

  /// 获取方向信息
  String getCompassInfo() {
    if (_lastHeading == null || _lastHeading!.heading == null) {
      return '⚠️ 无法获取方向信息';
    }

    final heading = _lastHeading!.heading!;
    final direction = getDirection(heading);
    final tip = getTip(heading);

    return '''🧭 方向

朝向: $direction（${heading.toStringAsFixed(0)}°）

$tip''';
  }

  /// 获取精确角度
  double? getExactHeading() {
    return _lastHeading?.heading;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

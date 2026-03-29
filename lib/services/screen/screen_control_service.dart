// 屏幕控制服务
//
// 亮度、方向控制

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 屏幕控制服务
class ScreenControlService extends ChangeNotifier {
  final ScreenBrightness _brightness = ScreenBrightness();

  double _currentBrightness = 0.5;
  bool _isAutoBrightness = false;
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;

  double get currentBrightness => _currentBrightness;
  bool get isAutoBrightness => _isAutoBrightness;
  DeviceOrientation get orientation => _orientation;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 获取当前亮度
      _currentBrightness = await _brightness.current;
      debugPrint('[Screen] 当前亮度: $_currentBrightness');

      // 检查是否支持自动亮度
      // Note: screen_brightness 插件可能不支持所有设备

      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 初始化失败: $e');
    }
  }

  /// 设置亮度 (0.0 - 1.0)
  Future<void> setBrightness(double value) async {
    try {
      // 限制范围
      final brightness = value.clamp(0.0, 1.0);
      
      await _brightness.setScreenBrightness(brightness);
      _currentBrightness = brightness;
      _isAutoBrightness = false;
      
      debugPrint('[Screen] 设置亮度: $brightness');
      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 设置亮度失败: $e');
    }
  }

  /// 重置亮度（恢复系统设置）
  Future<void> resetBrightness() async {
    try {
      await _brightness.resetScreenBrightness();
      _currentBrightness = await _brightness.current;
      _isAutoBrightness = true;
      
      debugPrint('[Screen] 重置亮度');
      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 重置亮度失败: $e');
    }
  }

  /// 增加亮度
  Future<void> increaseBrightness({double step = 0.1}) async {
    await setBrightness(_currentBrightness + step);
  }

  /// 降低亮度
  Future<void> decreaseBrightness({double step = 0.1}) async {
    await setBrightness(_currentBrightness - step);
  }

  /// 设置横屏
  Future<void> setLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _orientation = DeviceOrientation.landscapeLeft;
      
      debugPrint('[Screen] 设置横屏');
      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 设置横屏失败: $e');
    }
  }

  /// 设置竖屏
  Future<void> setPortrait() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _orientation = DeviceOrientation.portraitUp;
      
      debugPrint('[Screen] 设置竖屏');
      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 设置竖屏失败: $e');
    }
  }

  /// 自动旋转
  Future<void> setAutoRotate() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      debugPrint('[Screen] 设置自动旋转');
      notifyListeners();
    } catch (e) {
      debugPrint('[Screen] 设置自动旋转失败: $e');
    }
  }

  /// 获取亮度描述
  String getBrightnessDescription() {
    final percentage = (_currentBrightness * 100).round();
    
    if (percentage < 20) return '很暗';
    if (percentage < 40) return '较暗';
    if (percentage < 60) return '适中';
    if (percentage < 80) return '较亮';
    return '很亮';
  }

  /// 获取方向描述
  String getOrientationDescription() {
    switch (_orientation) {
      case DeviceOrientation.portraitUp:
      case DeviceOrientation.portraitDown:
        return '竖屏';
      case DeviceOrientation.landscapeLeft:
      case DeviceOrientation.landscapeRight:
        return '横屏';
      default:
        return '未知';
    }
  }

  @override
  void dispose() {
    resetBrightness();
    super.dispose();
  }
}

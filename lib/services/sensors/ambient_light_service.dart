// 环境光线服务
//
// 检测环境光线强度

import 'package:flutter/foundation.dart';
import 'package:light/light.dart';

/// 环境光线服务
class AmbientLightService extends ChangeNotifier {
  Light? _light;
  Stream<int>? _lightStream;
  int _luxValue = 0;

  int get luxValue => _luxValue;

  /// 初始化
  Future<void> initialize() async {
    try {
      _light = Light();
      
      // 监听光线变化
      _lightStream = _light!.lightSensorStream;
      _lightStream?.listen((int luxValue) {
        _luxValue = luxValue;
        notifyListeners();
      });

      debugPrint('[AmbientLight] 初始化完成');
    } catch (e) {
      debugPrint('[AmbientLight] 初始化失败: $e');
    }
  }

  /// 获取光线描述
  String getLightDescription() {
    if (_luxValue < 50) return '很暗';
    if (_luxValue < 200) return '较暗';
    if (_luxValue < 500) return '适中';
    if (_luxValue < 1000) return '明亮';
    return '很亮';
  }

  /// 获取建议
  String getSuggestion() {
    if (_luxValue < 50) {
      return '建议开启环境灯';
    } else if (_luxValue < 200) {
      return '建议降低屏幕亮度';
    } else if (_luxValue > 1000) {
      return '建议提高屏幕亮度或避免反光';
    } else {
      return '当前光线适宜';
    }
  }

  /// 获取光线信息
  String getLightInfo() {
    return '''💡 环境光线

强度: $_luxValue lux
状态: ${getLightDescription()}

建议: ${getSuggestion()}''';
  }

  @override
  void dispose() {
    _lightStream = null;
    super.dispose();
  }
}

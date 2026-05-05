// 海拔高度服务
//
// 通过气压计估算海拔

import 'package:flutter/foundation.dart';
import 'dart:math';

/// 海拔高度服务
class AltitudeService extends ChangeNotifier {
  double _pressure = 1013.25; // 标准大气压（hPa）
  double _altitude = 0;

  double get pressure => _pressure;
  double get altitude => _altitude;

  /// 更新气压值
  void updatePressure(double pressure) {
    _pressure = pressure;
    _altitude = _calculateAltitude(pressure);
    notifyListeners();
    debugPrint('[Altitude] 气压: ${pressure}hPa, 海拔: ${_altitude}m');
  }

  /// 计算海拔（国际标准大气模型）
  double _calculateAltitude(double pressure) {
    // 公式: h = 44330 * (1 - (P/P0)^0.1903)
    // P0 = 1013.25 hPa（海平面标准气压）
    const p0 = 1013.25;
    return 44330.0 * (1 - pow(pressure / p0, 0.1903)).toDouble();
  }

  /// 获取海拔描述
  String getAltitudeDescription() {
    if (_altitude < 100) return '平原地区';
    if (_altitude < 500) return '丘陵地区';
    if (_altitude < 1500) return '低山地区';
    if (_altitude < 3500) return '高山地区';
    return '高原地区';
  }

  /// 获取提示
  String getTip() {
    if (_altitude > 2500) {
      return '⚠️ 高海拔地区，注意高原反应';
    } else if (_altitude > 1500) {
      return '提示: 海拔较高，适当休息';
    }
    return '';
  }

  /// 获取海拔信息
  String getAltitudeInfo() {
    return '''🏔️ 海拔信息

海拔: ${_altitude.toStringAsFixed(0)} 米
气压: ${_pressure.toStringAsFixed(1)} hPa

${getAltitudeDescription()}
${getTip()}''';
  }
}

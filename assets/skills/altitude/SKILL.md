---
name: altitude
description: 查看当前海拔高度
---

# 海拔高度 Skill

通过气压计查看当前海拔。

## 使用方法

```markdown
用户：我现在海拔多高
助手：当前海拔 52 米
```

## 指令

```dart
import 'package:sensors_plus/sensors_plus.dart';

// 使用气压计估算海拔
final pressure = await _getBarometerReading();
final altitude = _calculateAltitude(pressure);

return '''🏔️ 海拔信息

海拔: ${altitude.toStringAsFixed(0)} 米
气压: ${pressure.toStringAsFixed(1)} hPa

${_getAltitudeDescription(altitude)}''';

double _calculateAltitude(double pressure) {
  // 使用国际标准大气模型
  // 海平面气压 = 1013.25 hPa
  return 44330 * (1 - pow(pressure / 1013.25, 0.1903));
}

String _getAltitudeDescription(double altitude) {
  if (altitude < 100) return '平原地区';
  if (altitude < 500) return '丘陵地区';
  if (altitude < 1500) return '低山地区';
  if (altitude < 3500) return '高山地区';
  return '高原地区（注意高原反应）';
}
```

## 应用场景
- 登山追踪
- 楼层检测
- 气压监测

## 实现状态
⚠️ 需要气压计硬件支持

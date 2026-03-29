---
name: compass
description: 指南针/方向感知
---

# 指南针 Skill

查看当前朝向。

## 使用方法

```markdown
用户：我现在面向哪个方向
助手：您当前面向东南方向（135°）
```

## 指令

```dart
import 'package:flutter_compass/flutter_compass.dart';

// 获取方向
final compass = FlutterCompass();
final heading = await compass.heading;

String _getDirection(double degrees) {
  if (degrees < 22.5 || degrees >= 337.5) return '北';
  if (degrees < 67.5) return '东北';
  if (degrees < 112.5) return '东';
  if (degrees < 157.5) return '东南';
  if (degrees < 202.5) return '南';
  if (degrees < 247.5) return '西南';
  if (degrees < 292.5) return '西';
  return '西北';
}

return '''🧭 方向

朝向: ${_getDirection(heading)}（${heading.toStringAsFixed(0)}°）

${_getTip(heading)}''';

String _getTip(double degrees) {
  // 根据朝向给出建议
  if (degrees > 45 && degrees < 225) {
    return '提示: 当前朝向阳面，注意防晒';
  }
  return '';
}
```

## 示例
- "我现在面向哪个方向"
- "指南针"
- "哪边是北"

## 实现状态
⚠️ 需要 flutter_compass 插件

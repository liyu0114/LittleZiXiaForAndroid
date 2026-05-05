---
name: current_location
description: 获取当前位置信息（经纬度、地址）
---

# Current Location Skill

获取设备的当前位置信息。

## 使用方法

```markdown
用户：我现在在哪里
助手：正在获取您的位置...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';

// 获取高精度位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// 格式化输出
return '''📍 当前位置信息

纬度: ${position.latitude.toStringAsFixed(6)}°
经度: ${position.longitude.toStringAsFixed(6)}°
海拔: ${position.altitude.toStringAsFixed(2)} 米
精度: ${position.accuracy.toStringAsFixed(2)} 米
速度: ${position.speed.toStringAsFixed(2)} 米/秒

时间: ${DateTime.fromMillisecondsSinceEpoch(position.timestamp!.millisecondsSinceEpoch)}
''';
```

## 示例
- "我现在在哪里"
- "获取当前位置"
- "我的位置"
- "我在哪"

## 实现状态
✅ 已实现（需要 L2 位置权限）

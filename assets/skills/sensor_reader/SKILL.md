---
name: sensor_reader
description: 读取传感器数据
---

# 传感器读取 Skill

读取设备的各种传感器数据。

## 使用方法

```markdown
用户：查看传感器数据
助手：📱 传感器数据\n\n加速度计: ...\n陀螺仪: ...\n磁力计: ...
```

## 指令

```dart
import 'package:sensors_plus/sensors_plus.dart';

// 加速度计
final accel = await accelerometerEvents.first;

// 陀螺仪
final gyro = await gyroscopeEvents.first;

// 磁力计
final mag = await magnetometerEvents.first;

return '''📱 传感器数据

加速度计:
  X: ${accel.x.toStringAsFixed(2)} m/s²
  Y: ${accel.y.toStringAsFixed(2)} m/s²
  Z: ${accel.z.toStringAsFixed(2)} m/s²

陀螺仪:
  X: ${gyro.x.toStringAsFixed(2)} rad/s
  Y: ${gyro.y.toStringAsFixed(2)} rad/s
  Z: ${gyro.z.toStringAsFixed(2)} rad/s

磁力计:
  X: ${mag.x.toStringAsFixed(2)} μT
  Y: ${mag.y.toStringAsFixed(2)} μT
  Z: ${mag.z.toStringAsFixed(2)} μT''';
```

## 示例
- "查看传感器数据"
- "读取加速度计"
- "陀螺仪数据"

## 实现状态
✅ 已实现（使用 sensors_plus 插件）

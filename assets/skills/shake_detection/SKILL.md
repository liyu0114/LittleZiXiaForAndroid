---
name: shake_detection
description: 摇晃手机触发操作（摇一摇）
---

# 摇晃检测 Skill

通过陀螺仪检测手机摇晃动作。

## 使用方法

```markdown
用户：摇一摇随机选
助手：[检测摇晃动作] 随机选择：...
```

## 指令

```dart
import 'package:sensors_plus/sensors_plus.dart';

// 监听加速度计
 accelerometerEvents.listen((AccelerometerEvent event) {
  final acceleration = sqrt(
    event.x * event.x + event.y * event.y + event.z * event.z
  );

  // 检测摇晃（加速度 > 阈值）
  if (acceleration > 20) {
    return '检测到摇晃！';
  }
});
```

## 应用场景
- 摇一摇随机选择
- 摇一摇刷新
- 摇一摇撤销
- 摇一摇切换

## 实现状态
⚠️ 需要 sensors_plus 插件

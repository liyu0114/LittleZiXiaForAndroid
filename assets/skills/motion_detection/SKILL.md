---
name: motion_detection
description: 检测手机运动状态
---

# 运动检测 Skill

检测用户当前的运动状态（走路、跑步、静止等）。

## 使用方法

```markdown
用户：我现在在做什么运动
助手：检测到您正在走路，速度约 1.2 m/s
```

## 指令

```dart
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';

// 获取活动识别
final activity = await ActivityRecognitionFlutter.activity;

String _getActivityDescription(ActivityType type) {
  switch (type) {
    case ActivityType.IN_VEHICLE:
      return '🚗 乘车中';
    case ActivityType.ON_BICYCLE:
      return '🚴 骑行中';
    case ActivityType.ON_FOOT:
      return '🚶 步行中';
    case ActivityType.RUNNING:
      return '🏃 跑步中';
    case ActivityType.STILL:
      return '🧘 静止';
    case ActivityType.TILTING:
      return '📱 移动设备';
    default:
      return '❓ 未知';
  }
}

return '''🏃 运动状态

状态: ${_getActivityDescription(activity.type)}
置信度: ${(activity.confidence * 100).toStringAsFixed(0)}%

${_getActivityTip(activity.type)}''';

String _getActivityTip(ActivityType type) {
  switch (type) {
    case ActivityType.IN_VEHICLE:
      return '提示: 乘车时注意安全';
    case ActivityType.RUNNING:
      return '加油！继续跑！';
    case ActivityType.ON_FOOT:
      return '散步有益健康';
    default:
      return '';
  }
}
```

## 应用场景
- 健康追踪
- 自动化场景触发
- 运动统计

## 示例
- "我现在在做什么"
- "检测运动状态"
- "我正在走路吗"

## 实现状态
⚠️ 需要 activity_recognition_flutter 插件

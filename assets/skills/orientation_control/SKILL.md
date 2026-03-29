---
name: orientation_control
description: 控制屏幕方向
---

# 屏幕方向 Skill

切换横屏/竖屏模式。

## 使用方法

```markdown
用户：切换横屏
助手：✅ 已切换到横屏模式
```

## 指令

```dart
import 'package:flutter/services.dart';

// 横屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

return '✅ 已切换到横屏模式';

// 竖屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
]);

return '✅ 已切换到竖屏模式';

// 自动旋转
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

return '✅ 已启用自动旋转';
```

## 示例
- "切换横屏"
- "竖屏"
- "自动旋转"

## 实现状态
✅ 已实现（Flutter 内置）

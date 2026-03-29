---
name: screen_control
description: 控制屏幕亮度/方向
---

# 屏幕控制 Skill

控制屏幕亮度和方向。

## 使用方法

```markdown
用户：把屏幕调暗一点
助手：已将屏幕亮度调低到 30%
```

## 指令

```dart
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/services.dart';

// 设置亮度
final brightness = ScreenBrightness();
await brightness.setScreenBrightness(0.3); // 0.0 - 1.0

return '✅ 已将屏幕亮度调低到 30%';

// 设置横屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

return '✅ 已切换到横屏模式';

// 设置竖屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
]);

return '✅ 已切换到竖屏模式';
```

## 应用场景
- 自动调节亮度
- 护眼模式
- 横竖屏切换

## 示例
- "把屏幕调暗"
- "切换横屏"
- "亮度调高一点"

## 实现状态
⚠️ 需要 screen_brightness 插件

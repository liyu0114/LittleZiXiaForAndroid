---
name: brightness_control
description: 控制屏幕亮度
---

# 亮度控制 Skill

调整屏幕亮度。

## 使用方法

```markdown
用户：把屏幕调暗一点
助手：✅ 已将亮度调低到 30%
```

## 指令

```dart
import 'package:screen_brightness/screen_brightness.dart';

final brightness = ScreenBrightness();
final current = await brightness.current;

// 降低亮度
final newBrightness = (current - 0.2).clamp(0.0, 1.0);
await brightness.setScreenBrightness(newBrightness);

return '✅ 已将亮度调低到 ${(newBrightness * 100).round()}%';
```

## 示例
- "把屏幕调暗"
- "亮度调高"
- "调亮一点"

## 实现状态
✅ 已实现（使用 screen_brightness 插件）

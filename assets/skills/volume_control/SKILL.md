---
name: volume_control
description: 控制音量
---

# 音量控制 Skill

控制媒体、铃声、通知音量。

## 使用方法

```markdown
用户：把音量调大一点
助手：已将媒体音量调高到 70%
```

## 指令

```dart
import 'package:volume_controller/volume_controller.dart';

// 获取当前音量
final volume = await VolumeController().getVolume();

// 设置音量
await VolumeController().setVolume(0.7); // 0.0 - 1.0

return '✅ 已将媒体音量调高到 70%';

// 静音
await VolumeController().setVolume(0.0);
return '🔇 已静音';
```

## 应用场景
- 快速调节音量
- 静音模式
- 音量查询

## 示例
- "把音量调大"
- "静音"
- "现在音量多少"

## 实现状态
⚠️ 需要 volume_controller 插件

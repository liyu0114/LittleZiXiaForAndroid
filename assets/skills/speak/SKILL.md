---
name: speak
description: 使用语音播报文本
---

# Speak Skill

使用 TTS（文字转语音）播报文本内容。

## 使用方法

```markdown
用户：请播报"你好世界"
助手：正在播报...
```

## 指令

```dart
use: speech(text="你好世界")
```

## 参数
- `text` (string): 要播报的文本

## 能力调用

本 Skill 调用基础能力：
- `speech` - 使用 TTS 播报文本

## 示例
- "播报你好"
- "说一句话"
- "语音播放测试"

## 实现状态
✅ 已实现（需要 TTS 服务）

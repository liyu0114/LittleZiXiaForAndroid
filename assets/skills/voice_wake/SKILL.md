---
name: voice_wake
description: 语音唤醒（"嘿紫霞"）
---

# 语音唤醒 Skill

通过语音唤醒词激活助手。

## 使用方法

```markdown
用户：嘿紫霞
助手：我在！有什么可以帮您的？
```

## 指令

```dart
import 'package:speech_to_text/speech_to_text.dart';

final speech = SpeechToText();
await speech.initialize();

await speech.listen(
  onResult: (result) {
    final words = result.recognizedWords;
    if (words.contains('紫霞') || words.contains('zixia')) {
      return '🎉 检测到唤醒词！';
    }
  },
  localeId: 'zh_CN',
);
```

## 唤醒词
- "嘿紫霞"
- "小紫霞"
- "紫霞"
- "hey 紫霞"
- "hey zixia"

## 示例
- "嘿紫霞"
- "小紫霞帮我查天气"

## 实现状态
✅ 已实现（使用 speech_to_text 插件）

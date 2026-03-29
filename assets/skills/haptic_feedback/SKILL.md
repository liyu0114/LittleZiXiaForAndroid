---
name: haptic_feedback
description: 触发震动反馈
---

# 震动反馈 Skill

触发手机的震动反馈。

## 使用方法

```markdown
用户：震一下
助手：[震动] ✅ 已触发震动反馈
```

## 指令

```dart
import 'package:flutter/services.dart';

// 轻震动
HapticFeedback.lightImpact();

// 中等震动
HapticFeedback.mediumImpact();

// 强震动
HapticFeedback.heavyImpact();

// 选择点击
HapticFeedback.selectionClick();

// 普通震动
HapticFeedback.vibrate();

return '✅ 已触发震动反馈';
```

## 震动类型
- `light` - 轻震动
- `medium` - 中等震动
- `heavy` - 强震动
- `selection` - 选择点击
- `vibrate` - 普通震动

## 示例
- "震一下"
- "震动反馈"
- "触感反馈"

## 实现状态
✅ 已实现（Flutter 内置）

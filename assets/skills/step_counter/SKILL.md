---
name: step_counter
description: 查看今天的步数
---

# 步数计数 Skill

查看今天走了多少步。

## 使用方法

```markdown
用户：我今天走了多少步
助手：今天已走 8,234 步，消耗约 320 卡路里
```

## 指令

```dart
import 'package:pedometer/pedometer.dart';

// 获取步数
final stepCount = await Pedometer.stepCount;

return '''🏃 今天运动数据

步数: ${stepCount.steps} 步
距离: ${(stepCount.steps * 0.7).toStringAsFixed(0)} 米（估算）
消耗: ${(stepCount.steps * 0.04).toStringAsFixed(0)} 卡路里（估算）

${_getStepEvaluation(stepCount.steps)}''';

String _getStepEvaluation(int steps) {
  if (steps < 3000) return '💪 继续加油！';
  if (steps < 6000) return '👍 不错！';
  if (steps < 10000) return '🌟 很棒！';
  return '🏆 太厉害了！';
}
```

## 示例
- "我今天走了多少步"
- "查看步数"
- "运动数据"

## 实现状态
⚠️ 需要 pedometer 插件

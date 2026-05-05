---
name: battery
description: 查看电池电量和充电状态
---

# 电池状态 Skill

查看设备电池电量和充电状态。

## 使用方法

```markdown
用户：电量还剩多少
助手：🔋 电池状态\n\n电量: 85%\n状态: 放电中 🔋
```

## 指令

```dart
import 'package:battery_plus/battery_plus.dart';

final battery = Battery();
final level = await battery.batteryLevel;
final state = await battery.batteryState;

String stateStr;
switch (state) {
  case BatteryState.charging:
    stateStr = '充电中 ⚡';
    break;
  case BatteryState.discharging:
    stateStr = '放电中 🔋';
    break;
  case BatteryState.full:
    stateStr = '已充满 ✅';
    break;
  default:
    stateStr = '未知';
}

String warning = '';
if (level < 20 && state != BatteryState.charging) {
  warning = '\n\n⚠️ 电量较低，建议充电';
}

return '''🔋 电池状态

电量: $level%
状态: $stateStr
$warning''';
```

## 示例
- "电量还剩多少"
- "电池状态"
- "我的手机还有多少电"

## 实现状态
✅ 已实现（使用 battery_plus 插件）

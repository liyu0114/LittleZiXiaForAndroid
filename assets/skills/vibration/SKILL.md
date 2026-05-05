---
name: vibration
version: 1.0.0
description: 振动反馈控制。触发各种振动模式（轻、中、重、自定义节奏）。用于触觉反馈、提醒、游戏交互。
metadata:
  openclaw:
    emoji: "📳"
    category: haptic
    platform: mobile
    requires:
      permissions: [vibration]
---

# 振动反馈 📳

控制手机振动马达，提供触觉反馈。

## 使用场景

- **操作反馈** - 按钮点击、切换开关
- **消息提醒** - 收到消息时振动
- **游戏交互** - 碰撞、打击感
- **计时提醒** - 倒计时结束
- **无障碍** - 视障用户的触觉提示

## 功能

### 1. 预设振动模式

```dart
// 轻振动
Vibration.light();

// 中等振动
Vibration.medium();

// 重振动
Vibration.heavy();

// 双击振动
Vibration.doubleClick();

// 成功反馈
Vibration.success();

// 警告反馈
Vibration.warning();

// 错误反馈
Vibration.error();
```

### 2. 自定义振动

```dart
// 振动 500ms
Vibration.vibrate(duration: 500);

// 节奏振动（振动100ms，暂停50ms，振动100ms）
Vibration.pattern([100, 50, 100]);

// 循环振动（3次）
Vibration.pattern([100, 100, 100, 100, 100, 100], repeat: 3);
```

### 3. 取消振动

```dart
Vibration.cancel();
```

## 使用方式

### AI 助手调用

```
用户：提醒我一下
AI：[振动提醒] 已提醒您！
```

```
用户：让手机振动
AI：[振动 200ms] 手机已振动。
```

```
用户：设置振动节奏
AI：请告诉我振动的节奏（例如：振动100ms，暂停50ms，振动100ms）
用户：振动三次，每次100ms，间隔50ms
AI：已设置为：[100, 50, 100, 50, 100]
```

### 执行流程

1. **检查权限**
   ```dart
   if (await Vibration.hasPermission()) {
     // 执行振动
   } else {
     // 请求权限
   }
   ```

2. **触发振动**
   ```dart
   // 方式1：预设模式
   await Vibration.medium();

   // 方式2：自定义
   await Vibration.vibrate(duration: 200);
   ```

3. **可选：等待完成**
   ```dart
   await Vibration.vibrate(duration: 500);
   // 振动结束后继续
   ```

## 技术实现

### Flutter（vibration 包）

```dart
import 'package:vibration/vibration.dart';

// 检查设备是否支持振动
if (await Vibration.hasVibrator()) {
  // 振动 200ms
  await Vibration.vibrate(duration: 200);
}

// 节奏振动
await Vibration.vibrate(pattern: [100, 50, 100]);

// 取消振动
Vibration.cancel();
```

### Android（HapticFeedbackConstants）

```kotlin
// 使用系统预定义的触觉反馈
view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)

// 使用 Vibrator 服务
val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
} else {
    vibrator.vibrate(200)
}
```

### iOS（UIFeedbackGenerator）

```swift
// 使用系统触觉反馈
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()

// 通知反馈
let notificationGenerator = UINotificationFeedbackGenerator()
notificationGenerator.notificationOccurred(.success)

// 选择反馈
let selectionGenerator = UISelectionFeedbackGenerator()
selectionGenerator.selectionChanged()
```

## 使用示例

### 按钮点击反馈

```dart
TextButton(
  onPressed: () {
    Vibration.light();
    // 执行操作
  },
  child: Text("点击我"),
)
```

### 消息提醒

```dart
void onMessageReceived(Message message) {
  if (message.isImportant) {
    Vibration.pattern([100, 50, 100, 50, 100]);
  } else {
    Vibration.light();
  }
}
```

### 倒计时提醒

```dart
Timer countdown = Timer.periodic(Duration(seconds: 1), (timer) {
  if (timer.tick <= 3) {
    Vibration.medium();  // 最后 3 秒每秒振动
  }
});
```

### 游戏交互

```dart
// 碰撞
void onCollision() {
  Vibration.heavy();
}

// 得分
void onScore() {
  Vibration.success();
}

// 游戏结束
void onGameOver() {
  Vibration.pattern([200, 100, 200, 100, 500]);
}
```

### 节拍器

```dart
Timer beatTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
  Vibration.light();
});
```

## 预设模式详解

| 模式 | 描述 | 使用场景 |
|-----|------|---------|
| `light` | 轻柔振动 | 按钮点击、选项切换 |
| `medium` | 中等振动 | 常规提醒、滑动到边界 |
| `heavy` | 强烈振动 | 重要提醒、确认删除 |
| `doubleClick` | 双击振动 | 撤销操作、切换模式 |
| `success` | 成功反馈 | 操作成功、任务完成 |
| `warning` | 警告反馈 | 操作异常、需要注意 |
| `error` | 错误反馈 | 操作失败、输入错误 |

## 配置

### 全局配置

```yaml
vibration:
  enabled: true
  default_intensity: "medium"  # light, medium, heavy
  max_duration: 1000  # 最大振动时长(ms)
```

### 用户偏好

```dart
class VibrationSettings {
  bool enabled;
  Intensity defaultIntensity;
  bool hapticFeedbackEnabled;  // 系统触觉反馈
}
```

## 注意事项

### Android

- 需要 `VIBRATE` 权限
- 部分设备振动马达效果不同
- 后台应用可能无法振动

### iOS

- 无需权限，但只能使用系统预定义的触觉反馈
- iPhone 7 以下设备振动效果有限
- 必须在主线程调用

### 通用

- **避免过度使用** - 持续振动会耗电并打扰用户
- **控制强度** - 不要用过强的振动
- **尊重用户设置** - 检查用户是否禁用了振动

## 常见问题

**Q: 没有振动？**
A:
- 检查设备是否支持振动
- 检查权限（Android）
- 检查是否在静音模式（可能禁用振动）

**Q: 振动太弱？**
A: 尝试使用 `heavy` 模式，或增加持续时间。

**Q: 可以调节振动强度吗？**
A: Android 8.0+ 支持调节振幅（0-255），iOS 只能使用预设强度。

**Q: 后台可以振动吗？**
A: Android 需要前台服务，iOS 后台应用无法振动。

## 权限需求

- ✅ **Android** - `VIBRATE` 权限
- ✅ **iOS** - 无需权限

---

*触觉反馈，感知交互。* 📳

**作者：** OpenClaw Community

---
name: shake-trigger
version: 1.0.0
description: 摇一摇触发器。检测手机摇动并执行预设动作（如撤销、刷新、发送）。支持灵敏度调节。
metadata:
  openclaw:
    emoji: "📳"
    category: interaction
    platform: mobile
    requires:
      permissions: [accelerometer]
---

# 摇一摇触发器 📳

通过摇动手机快速触发操作，解放双手。

## 使用场景

- **撤销操作** - 摇一摇撤销最后一条消息
- **刷新内容** - 摇一摇刷新当前页面
- **快速发送** - 摇一摇发送当前输入
- **切换模式** - 摇一摇切换深色/浅色模式
- **触发语音** - 摇一摇开始语音输入

## 功能

### 检测摇动

使用加速度计检测手机摇动：

```
触发条件：
- 加速度 > 阈值（默认 15 m/s²）
- 持续时间 > 100ms
- 冷却时间 500ms（防止连续触发）
```

### 灵敏度设置

| 等级 | 阈值 (m/s²) | 体验 |
|-----|------------|------|
| 高灵敏度 | 12 | 轻摇即触发 |
| 默认 | 15 | 正常力度 |
| 低灵敏度 | 20 | 需要用力摇 |

### 可配置动作

```yaml
shake-trigger:
  action: "undo" | "refresh" | "send" | "custom"
  sensitivity: "high" | "medium" | "low"
  haptic: true | false  # 触发时振动反馈
  cooldown: 500  # 冷却时间(ms)
```

## 使用方式

### AI 助手调用

```
用户：摇一摇撤销
AI：已启用摇一摇撤销功能。摇动手机即可撤销最后一条消息。
```

```
用户：把摇一摇改成刷新
AI：已将摇一摇动作改为刷新当前内容。
```

### 执行流程

1. **启动监听**
   ```dart
   ShakeTrigger.startListening(
     sensitivity: Sensitivity.medium,
     onShake: () {
       // 执行预设动作
       executeAction(config.action);
       // 振动反馈
       if (config.haptic) {
         HapticFeedback.mediumImpact();
       }
     },
   );
   ```

2. **检测到摇动**
   - 检查加速度计数据
   - 超过阈值 → 触发回调
   - 执行预设动作
   - 振动反馈（可选）

3. **停止监听**
   ```dart
   ShakeTrigger.stopListening();
   ```

## 技术实现

### 摇动检测算法

```dart
// 加速度计数据流
accelerometerEvents.listen((event) {
  final acceleration = sqrt(
    event.x * event.x +
    event.y * event.y +
    event.z * event.z
  );

  // 检测是否超过阈值
  if (acceleration > threshold && !isInCooldown) {
    onShakeDetected();
    startCooldown();
  }
});
```

### 冷却机制

```dart
bool _isInCooldown = false;

void startCooldown() {
  _isInCooldown = true;
  Future.delayed(Duration(milliseconds: cooldown), () {
    _isInCooldown = false;
  });
}
```

## 配置示例

### 撤销消息

```yaml
action: undo
sensitivity: medium
haptic: true
cooldown: 500
```

### 刷新内容

```yaml
action: refresh
sensitivity: low
haptic: true
cooldown: 1000
```

### 自定义动作

```yaml
action: custom
customAction: "toggleTheme"
sensitivity: high
haptic: false
cooldown: 300
```

## 注意事项

- **省电** - 不使用时停止监听加速度计
- **防误触** - 设置合理的阈值和冷却时间
- **权限** - 需要加速度计访问权限（Android 通常无需用户授权）
- **兼容性** - 大部分现代手机都支持加速度计

## 常见问题

**Q: 太灵敏，容易误触？**
A: 调低灵敏度到 "low"，或增加冷却时间。

**Q: 摇了没反应？**
A: 检查是否启用了监听，或调高灵敏度。

**Q: 耗电吗？**
A: 加速度计是低功耗传感器，影响很小。但不使用时应停止监听。

---

*摇一摇，更高效。* 📳

**作者：** OpenClaw Community

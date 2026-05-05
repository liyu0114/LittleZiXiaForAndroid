---
name: emergency-sos
version: 1.0.0
description: 紧急求救。一键发送位置和求救信息给预设联系人。支持连续按电源键触发、自动拨打紧急电话。
metadata:
  openclaw:
    emoji: "🆘"
    category: safety
    platform: mobile
    requires:
      permissions: [location, sms, phone, contacts]
---

# 紧急求救 🆘

关键时刻一键求救，自动发送位置信息。

## 使用场景

- **遇到危险** - 快速向亲友求助
- **紧急情况** - 一键拨打 110/120/119
- **位置共享** - 自动发送精确位置
- **连续触发** - 紧急时连按电源键激活

## 功能

### 1. 一键发送 SOS

向预设联系人发送：
- 📍 **当前位置**（精确到米）
- 📝 **求救信息**（可自定义）
- 🕐 **时间戳**
- 📱 **设备信息**（型号、电量）

**示例消息：**
```
🆘 紧急求助！

📍 位置：北京市海淀区中关村大街 27 号
🕒 时间：2026-04-06 19:30:25
📱 设备：Huawei P40 Pro（电量 45%）

我可能遇到了危险，请立即联系我或报警！
```

### 2. 连续按电源键触发

- **5 秒内按 5 次电源键** → 自动触发 SOS
- 无需解锁屏幕
- 静默发送（不显示界面，避免激怒对方）

### 3. 自动拨打紧急电话

配置紧急号码：
- 🚔 **110** - 报警
- 🚑 **120** - 急救
- 🚒 **119** - 火警

### 4. 位置更新

每 30 秒自动更新一次位置并发送，持续 10 分钟。

## 配置

### 预设联系人

```yaml
emergency-contacts:
  - name: "爸爸"
    phone: "138****1234"
    relation: "父亲"
  - name: "妈妈"
    phone: "139****5678"
    relation: "母亲"
  - name: "好友"
    phone: "137****9012"
    relation: "朋友"
```

### SOS 消息模板

```yaml
message-template: |
  🆘 紧急求助！

  📍 位置：{location}
  🕒 时间：{timestamp}
  📱 设备：{device}

  {custom_message}
```

### 触发方式

```yaml
triggers:
  power_button:
    enabled: true
    press_count: 5
    time_window: 5000  # 5 秒内
  voice:
    enabled: true
    phrases: ["救命", "报警", "SOS"]
  manual:
    enabled: true  # 界面按钮
```

## 使用方式

### AI 助手调用

```
用户：帮我发送求救信息
AI：确认发送 SOS 给紧急联系人（爸爸、妈妈）？
    当前位置：北京市海淀区中关村大街 27 号
    [确认] [取消]
```

```
用户：设置紧急联系人
AI：请告诉我紧急联系人的姓名和电话号码。
用户：爸爸 138****1234
AI：已添加"爸爸"（138****1234）为紧急联系人。
```

### 执行流程

1. **触发 SOS**
   ```dart
   EmergencySOS.trigger(
     reason: "manual", // 或 "power_button", "voice"
     customMessage: "", // 可选附加信息
   );
   ```

2. **获取位置**
   ```dart
   final location = await LocationService.getCurrentPosition();
   // 精度：高（GPS）
   ```

3. **发送消息**
   ```dart
   for (final contact in emergencyContacts) {
     await SMSService.send(
       recipient: contact.phone,
       message: buildSOSMessage(location, customMessage),
     );
   }
   ```

4. **位置跟踪**（可选）
   ```dart
   // 每 30 秒更新一次位置，持续 10 分钟
   LocationTracker.start(
     interval: Duration(seconds: 30),
     duration: Duration(minutes: 10),
     onUpdate: (location) {
       sendLocationUpdate(location);
     },
   );
   ```

5. **拨打紧急电话**（可选）
   ```dart
   PhoneService.call("110");
   ```

## 技术实现

### 电源键检测（Android）

```kotlin
// 监听屏幕开关事件
override fun dispatchKeyEvent(event: KeyEvent): Boolean {
    if (event.keyCode == KeyEvent.KEYCODE_POWER) {
        powerPressCount++
        if (powerPressCount >= 5 && withinTimeWindow()) {
            triggerEmergencySOS()
        }
    }
    return super.dispatchKeyEvent(event)
}
```

### 静默发送

```dart
// 后台服务，不显示界面
Future<void> sendSilentSOS() async {
  // 1. 获取位置（后台）
  final location = await LocationService.getBackgroundPosition();

  // 2. 发送短信（后台）
  await SMSService.sendBackground(recipient, message);

  // 3. 显示最小化通知
  NotificationService.show(
    title: "SOS 已发送",
    body: "已通知紧急联系人",
    silent: true,
  );
}
```

### 位置格式化

```dart
String formatLocation(LatLng position) {
  // 反向地理编码
  final address = await ReverseGeocoding.getAddress(position);
  return "${address.street}, ${address.city}";
}
```

## 安全考虑

- **隐私保护** - SOS 记录加密存储，不上传云端
- **防误触** - 需要连续按 5 次电源键
- **静默模式** - 可配置不显示界面、不发声
- **权限最小化** - 只在触发时获取位置

## 配置示例

### 基础配置

```yaml
emergency-contacts:
  - name: "家人"
    phone: "138****1234"

triggers:
  power_button: true
  voice: false
  manual: true

location_update:
  enabled: true
  interval: 30  # 秒
  duration: 600  # 秒
```

### 完整配置

```yaml
emergency-contacts:
  - name: "爸爸"
    phone: "138****1234"
  - name: "妈妈"
    phone: "139****5678"
  - name: "110"
    phone: "110"
    auto_call: true

message-template: |
  🆘 紧急求助！
  📍 位置：{location}
  🕒 时间：{timestamp}
  📱 设备：{device}
  {custom_message}

triggers:
  power_button:
    enabled: true
    press_count: 5
    time_window: 5000
  voice:
    enabled: true
    phrases: ["救命", "报警", "SOS"]
  manual: true

location_update:
  enabled: true
  interval: 30
  duration: 600

silent_mode: true  # 触发时不显示界面
haptic_feedback: true  # 振动确认
```

## 权限需求

- ✅ **定位** - 获取当前位置
- ✅ **短信** - 发送 SOS 消息
- ✅ **电话** - 拨打紧急电话（可选）
- ✅ **通讯录** - 选择紧急联系人（可选）
- ✅ **后台定位** - 持续更新位置（可选）

## 常见问题

**Q: 会误触发吗？**
A: 需要在 5 秒内连续按 5 次电源键，误触概率极低。

**Q: 对方收不到短信？**
A: 检查短信权限、联系人号码是否正确、手机信号。

**Q: 位置不准？**
A: 确保开启 GPS，在室外精度更高。室内可能使用网络定位。

**Q: 耗电吗？**
A: 只在触发时获取位置，平时不耗电。如开启持续位置更新，会消耗一定电量。

---

*关键时刻，一键救命。* 🆘

**作者：** OpenClaw Community

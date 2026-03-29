---
name: notification
description: 发送系统通知
---

# 通知 Skill

## 功能
发送本地系统通知。

## 使用方法

### 通过代码调用
```dart
await FlutterLocalNotificationsPlugin().show(
  0,
  '标题',
  '内容',
  NotificationDetails(
    android: AndroidNotificationDetails(
      'channel_id',
      'channel_name',
    ),
  ),
);
```

## 参数
- `title` (string): 通知标题
- `body` (string): 通知内容
- `schedule` (string): 定时（可选）

## 权限要求
- 通知权限 (POST_NOTIFICATIONS)

## 示例
- "5分钟后提醒我开会"
- "发送通知：任务完成"
- "提醒我吃药"

## 能力层级
- 属于 L2 增强模式
- 需要开启 L2 能力层

## 实现状态
⚠️ 部分实现（需要添加 flutter_local_notifications 插件）

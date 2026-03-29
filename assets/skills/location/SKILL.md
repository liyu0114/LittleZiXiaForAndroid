---
name: location
description: 获取设备位置信息
---

# 位置 Skill

## 功能
获取设备的 GPS 位置信息。

## 使用方法

### 通过代码调用
```dart
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
```

## 参数
- `accuracy` (string): 精度（high/medium/low）

## 权限要求
- 位置权限 (ACCESS_FINE_LOCATION)
- 位置权限 (ACCESS_COARSE_LOCATION)

## 示例
- "我在哪里"
- "获取当前位置"
- "查一下我的位置"

## 能力层级
- 属于 L2 增强模式
- 需要开启 L2 能力层

## 实现状态
⚠️ 部分实现（需要添加 geolocator 插件）

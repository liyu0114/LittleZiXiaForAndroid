---
name: location
description: 获取设备位置信息并转换为具体地点名称
---

# 位置 Skill

## 功能
获取设备的 GPS 位置信息，并转换为人类可读的地点名称。

## 步骤 1：获取经纬度

```dart
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
// 返回：纬度 39.9042, 经度 116.4074
```

## 步骤 2：逆地理编码

```http
GET https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lon}&zoom=10&accept-language=zh
```

## 参数
- `accuracy` (string): 精度（high/medium/low）

## 返回格式

📍 **你的位置：**
- **地点：** 北京市东城区
- **详细地址：** 北京市东城区东华门街道, 北京市, 100000
- **经纬度：** 39.9042, 116.4074

## 权限要求
- 位置权限 (ACCESS_FINE_LOCATION)
- 位置权限 (ACCESS_COARSE_LOCATION)

## 示例
- "我在哪"
- "我在哪里"
- "获取当前位置"
- "查一下我的位置"

## 实现状态
✅ 已实现（需要 geolocator 插件 + 网络请求）

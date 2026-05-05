---
name: nearby_restaurants
description: 搜索附近的餐厅、美食
---

# Nearby Restaurants Skill

基于当前位置搜索附近的餐厅和美食。

## 使用方法

```markdown
用户：附近有什么好吃的
助手：正在搜索附近的餐厅...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';

// 1. 获取当前位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium,
);

// 2. 搜索参数
final radius = params['radius'] ?? 1000; // 默认 1km 范围

// 3. 返回位置信息（实际应用需要地图 API）
return '''🍜 正在搜索附近美食...

您的位置:
- 纬度: ${position.latitude.toStringAsFixed(6)}
- 经度: ${position.longitude.toStringAsFixed(6)}
- 搜索范围: ${radius}米

（需要地图 API 支持，如高德、百度地图）''';
```

## 参数
- `radius` (int): 搜索半径（米），默认 1000
- `type` (string): 餐厅类型（可选）

## 示例
- "附近有什么好吃的"
- "找最近的餐厅"
- "周围有啥美食"
- "搜索附近的饭店"

## 实现状态
⚠️ 框架已实现，需要地图 API

---
name: nearby_gas_stations
description: 搜索附近的加油站
---

# Nearby Gas Stations Skill

基于当前位置搜索附近的加油站。

## 使用方法

```markdown
用户：最近的加油站在哪
助手：正在搜索附近的加油站...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';

// 1. 获取当前位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium,
);

// 2. 搜索参数
final radius = params['radius'] ?? 5000; // 默认 5km 范围

// 3. 返回位置信息（实际应用需要地图 API）
return '''⛽ 正在搜索附近加油站...

您的位置:
- 纬度: ${position.latitude.toStringAsFixed(6)}
- 经度: ${position.longitude.toStringAsFixed(6)}
- 搜索范围: ${radius}米

（需要地图 API 支持）''';
```

## 参数
- `radius` (int): 搜索半径（米），默认 5000

## 示例
- "最近的加油站在哪"
- "附近有加油站吗"
- "找加油站"
- "我周围有加油站吗"

## 实现状态
⚠️ 框架已实现，需要地图 API

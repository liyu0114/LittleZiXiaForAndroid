---
name: nearby_hospitals
description: 搜索附近的医院、药店
---

# Nearby Hospitals Skill

基于当前位置搜索附近的医院和药店。

## 使用方法

```markdown
用户：附近有医院吗
助手：正在搜索附近的医院...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';

// 1. 获取当前位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium,
);

// 2. 搜索参数
final type = params['type'] ?? 'hospital'; // hospital 或 pharmacy
final radius = params['radius'] ?? 10000; // 默认 10km 范围

// 3. 返回位置信息（实际应用需要地图 API）
final typeName = type == 'pharmacy' ? '药店' : '医院';

return '''🏥 正在搜索附近$typeName...

您的位置:
- 纬度: ${position.latitude.toStringAsFixed(6)}
- 经度: ${position.longitude.toStringAsFixed(6)}
- 搜索范围: ${radius}米

（需要地图 API 支持）''';
```

## 参数
- `type` (string): hospital（医院）或 pharmacy（药店）
- `radius` (int): 搜索半径（米），默认 10000

## 示例
- "附近有医院吗"
- "最近的药店在哪"
- "找医院"
- "我周围有诊所吗"

## 实现状态
⚠️ 框架已实现，需要地图 API

---
name: distance_to
description: 计算到某地的距离
---

# Distance To Skill

计算当前位置到目标地点的距离。

## 使用方法

```markdown
用户：我离北京有多远
助手：正在计算距离...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';

// 1. 获取当前位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// 2. 目标地点（从参数获取）
final targetLat = params['latitude'] as double?;
final targetLng = params['longitude'] as double?;
final targetName = params['name']?.toString() ?? '目标地点';

if (targetLat == null || targetLng == null) {
  // 如果没有坐标，使用地理编码（需要 API）
  return '⚠️ 请提供目标地点的坐标，或使用地图 API 进行地理编码';
}

// 3. 计算距离（使用 Haversine 公式）
final distance = Geolocator.distanceBetween(
  position.latitude,
  position.longitude,
  targetLat,
  targetLng,
);

// 4. 格式化输出
String distanceStr;
if (distance < 1000) {
  distanceStr = '${distance.toStringAsFixed(0)} 米';
} else {
  distanceStr = '${(distance / 1000).toStringAsFixed(2)} 公里';
}

return '''📍 距离计算

您的位置: ${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°
目标地点: $targetName

直线距离: $distanceStr''';
```

## 参数
- `name` (string): 目标地点名称
- `latitude` (double): 目标纬度
- `longitude` (double): 目标经度

## 示例
- "我离北京有多远"
- "计算到上海的距离"
- "我离天安门广场多远"

## 实现状态
✅ 已实现（需要 L2 位置权限）

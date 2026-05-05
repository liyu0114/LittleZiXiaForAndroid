---
name: local_weather
description: 基于当前位置查询天气（自动获取所在城市）
---

# Local Weather Skill

根据您当前的位置自动查询当地天气。

## 使用方法

```markdown
用户：我现在所在城市今天的天气
助手：正在获取您的位置并查询天气...
```

## 指令

```dart
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// 1. 获取当前位置
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// 2. 使用坐标查询天气（Open-Meteo API，免费无需 API key）
final response = await http.get(
  Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto'),
);

// 3. 解析返回
if (response.statusCode == 200) {
  return response.body;
} else {
  return '天气查询失败';
}
```

## 示例
- "我现在所在城市今天的天气"
- "这里天气怎么样"
- "我这里多少度"

## 实现状态
✅ 已实现（需要 L2 位置权限）

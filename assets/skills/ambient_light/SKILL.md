---
name: ambient_light
description: 检测环境光线强度
---

# 环境光线 Skill

检测当前环境光线强度，自动调节屏幕或提供建议。

## 使用方法

```markdown
用户：现在光线怎么样
助手：环境光线较暗，建议开启护眼模式
```

## 指令

```dart
import 'package:light/light.dart';

// 获取光线强度
final light = Light();
final luxValue = await light.light;

String _getLightDescription(int lux) {
  if (lux < 50) return '很暗（建议开灯）';
  if (lux < 200) return '较暗（护眼模式）';
  if (lux < 500) return '适中（舒适）';
  if (lux < 1000) return '明亮（正常）';
  return '很亮（注意护眼）';
}

return '''💡 环境光线

强度: $luxValue lux
状态: ${_getLightDescription(luxValue)}

建议: ${_getSuggestion(luxValue)}''';

String _getSuggestion(int lux) {
  if (lux < 50) return '建议开启环境灯';
  if (lux < 200) return '建议降低屏幕亮度';
  if (lux > 1000) return '建议提高屏幕亮度或避免反光';
  return '当前光线适宜';
}
```

## 应用场景
- 自动调节屏幕亮度
- 护眼提醒
- 环境感知

## 实现状态
⚠️ 需要 light 插件

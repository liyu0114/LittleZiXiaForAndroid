---
name: network_status
description: 查看网络连接状态
---

# 网络状态 Skill

查看设备的网络连接状态。

## 使用方法

```markdown
用户：网络状态怎么样
助手：🌐 网络状态\n\n连接类型: WiFi 📶\n状态: 已连接 ✅
```

## 指令

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivity = Connectivity();
final results = await connectivity.checkConnectivity();

if (results.contains(ConnectivityResult.none)) {
  return '❌ 无网络连接';
}

final connections = <String>[];
for (final result in results) {
  switch (result) {
    case ConnectivityResult.wifi:
      connections.add('WiFi 📶');
      break;
    case ConnectivityResult.mobile:
      connections.add('移动数据 📱');
      break;
    case ConnectivityResult.ethernet:
      connections.add('以太网 🔌');
      break;
    case ConnectivityResult.bluetooth:
      connections.add('蓝牙 📻');
      break;
    default:
      connections.add('其他');
  }
}

return '''🌐 网络状态

连接类型: ${connections.join(', ')}
状态: 已连接 ✅''';
```

## 示例
- "网络状态怎么样"
- "有没有网"
- "WiFi 连接了吗"

## 实现状态
✅ 已实现（使用 connectivity_plus 插件）

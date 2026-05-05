---
name: bluetooth_scanner
description: 扫描附近的蓝牙设备
---

# 蓝牙扫描 Skill

扫描附近的蓝牙设备。

## 使用方法

```markdown
用户：附近有什么蓝牙设备
助手：正在扫描蓝牙设备...
```

## 指令

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// 检查蓝牙状态
if (!await FlutterBluePlus.isOn) {
  return '❌ 蓝牙未开启';
}

// 扫描设备
final devices = <BluetoothDevice>[];
await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

FlutterBluePlus.scanResults.listen((results) {
  devices.addAll(results.map((r) => r.device));
});

// 等待扫描完成
await Future.delayed(Duration(seconds: 4));
await FlutterBluePlus.stopScan();

// 去重
final uniqueDevices = devices.toSet().toList();

return '''📡 蓝牙设备扫描

找到 ${uniqueDevices.length} 个设备:

${uniqueDevices.map((d) => '• ${d.name ?? '未知设备'} (${d.id})').join('\n')}''';
```

## 应用场景
- 查找丢失的蓝牙设备
- 设备配对
- 智能家居控制

## 示例
- "附近有什么蓝牙设备"
- "扫描蓝牙"
- "我的耳机在哪"

## 实现状态
⚠️ 需要 flutter_blue_plus 插件

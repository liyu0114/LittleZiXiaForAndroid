---
name: nfc_reader
description: 读取 NFC 标签
---

# NFC 读取 Skill

读取 NFC 标签内容。

## 使用方法

```markdown
用户：读取这个 NFC 标签
助手：[打开 NFC 扫描] 检测到 NFC 标签...
```

## 指令

```dart
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

// 检查 NFC 可用性
final availability = await FlutterNfcKit.nfcAvailability;
if (availability != NFCAvailability.available) {
  return '❌ 设备不支持 NFC 或未开启';
}

// 读取标签
final tag = await FlutterNfcKit.poll();

return '''📱 NFC 标签信息

类型: ${tag.type}
ID: ${tag.id}
标准: ${tag.standard}
协议: ${tag.ndefAvailable ? 'NDEF' : '其他'}

${tag.ndefAvailable ? 'NDEF 内容:\n${tag.ndefMessage}' : ''}''';
```

## 应用场景
- 读取 NFC 名片
- 读取智能标签
- 门禁卡信息
- 支付卡识别

## 示例
- "读取这个 NFC 标签"
- "扫描门禁卡"
- "读取 NFC"

## 实现状态
⚠️ 需要 flutter_nfc_kit 插件

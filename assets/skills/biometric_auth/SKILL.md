---
name: biometric_auth
description: 生物识别认证（指纹/面部）
---

# 生物识别 Skill

通过指纹或面部识别进行安全认证。

## 使用方法

```markdown
用户：用指纹解锁
助手：[弹出指纹识别] ✅ 认证成功
```

## 指令

```dart
import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();
final canCheck = await auth.canCheckBiometrics;

if (!canCheck) {
  return '❌ 设备不支持生物识别';
}

final biometrics = await auth.getAvailableBiometrics();
final types = biometrics.map((t) {
  switch (t) {
    case BiometricType.fingerprint: return '指纹';
    case BiometricType.face: return '面部';
    case BiometricType.iris: return '虹膜';
    default: return '其他';
  }
}).join('、');

final authenticated = await auth.authenticate(
  localizedReason: '请验证身份',
  options: AuthenticationOptions(biometricOnly: true),
);

if (authenticated) {
  return '✅ 认证成功\n\n可用方式: $types';
} else {
  return '❌ 认证失败';
}
```

## 示例
- "用指纹解锁"
- "面部识别"
- "验证身份"

## 实现状态
✅ 已实现（使用 local_auth 插件）

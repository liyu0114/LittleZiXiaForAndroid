---
name: shell
description: 执行 Shell 命令（需要 ADB）
---

# Shell Skill

## 功能
执行系统 Shell 命令。

## 使用方法

### 通过代码调用
```dart
final result = await Process.run(
  'ls',
  ['-la'],
);
```

## 参数
- `command` (string): 命令名称
- `args` (list): 命令参数

## 权限要求
- ADB 调试权限
- 需要 L3 系统模式授权

## 示例
- "列出当前目录文件"
- "执行 ls -la"
- "查看系统日志"

## 能力层级
- 属于 L3 系统模式
- 需要开启 L3 能力层并授权 ADB

## 安全警告
⚠️ 此功能需要 ADB 调试权限，可能存在安全风险。
请仅在信任此应用的情况下使用。

## 实现状态
⚠️ 框架已实现，但需要 ADB 授权后才能使用

---
name: remote_command
description: 在远程设备上执行命令
---

# 远程命令 Skill

## 功能
通过 Gateway 在远程设备（Windows/Linux 龙虾）上执行命令。

## 使用方法

### 通过 Gateway API
```http
POST http://gateway:18789/api/execute
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "command": "ls -la",
  "working_directory": "/home/user"
}
```

## 参数
- `command` (string): 要执行的命令
- `working_directory` (string): 工作目录（可选）

## 配置要求
- 需要配置远程 Gateway URL 和 Token
- 需要开启 L4 远程模式

## 示例
- "在远程执行 ls"
- "帮我远程运行脚本"
- "查看远程服务器状态"

## 能力层级
- 属于 L4 远程模式
- 需要开启 L4 能力层并配置 Gateway

## 实现状态
⚠️ 框架已实现，但需要配置 Gateway 后才能使用

# OpenClaw 移动端客户端 - 项目报告

**版本:** v1.5.1  
**构建日期:** 2026-03-20  
**APK 文件:** `OpenClaw_v1.5.1_20260320_0750.apk`

---

## 一、项目概述

OpenClaw 移动端客户端是一个 Flutter 应用，用于远程连接和控制 OpenClaw Gateway。用户可以通过手机与 Gateway 上的 AI Agent 进行双向通信，发送指令并接收响应。

### 核心功能

- **WebSocket 双向通信** - 实时消息收发
- **HTTP API 支持** - 消息发送和状态查询
- **任务状态追踪** - 实时显示 AI 执行步骤
- **配置管理** - Gateway URL 和 Token 持久化存储
- **Material Design 3** - 现代化 UI 设计

---

## 二、技术架构

### 2.1 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 语言 | Dart |
| 状态管理 | Provider |
| 本地存储 | SharedPreferences |
| 网络通信 | HTTP + WebSocket |
| UI 组件 | Material Design 3 |

### 2.2 项目结构

```
mobile-client/
├── openclaw_app/          # 主应用
│   ├── lib/
│   │   ├── main.dart      # 入口
│   │   ├── providers/     # 状态管理
│   │   ├── screens/       # 页面
│   │   ├── widgets/       # 组件
│   │   └── theme/         # 主题
│   └── assets/            # 资源文件
├── openclaw_sdk/          # SDK 模块
│   ├── lib/
│   │   ├── openclaw_sdk.dart
│   │   ├── models/        # 数据模型
│   │   └── services/      # API 服务
│   └── ...
└── docs/                  # 文档
```

### 2.3 通信协议

**HTTP API:**
- `POST /chat` - 发送消息
- `GET /status` - 查询 Gateway 状态

**WebSocket:**
- 连接路径: `/ws`
- 消息格式: JSON
- 支持双向实时通信

---

## 三、功能详解

### 3.1 配置页面

- Gateway URL 输入
- Token 输入（默认已内置）
- 连接测试按钮
- 配置保存到本地

### 3.2 会话页面

- 消息列表显示（用户/Agent 区分）
- 消息输入框
- 发送按钮
- 任务状态实时显示

### 3.3 连接状态

- 顶部状态栏显示连接状态
- 一键连接/断开
- 自动重连（待实现）

---

## 四、安装与使用

### 4.1 系统要求

- Android 5.0 (API 21) 或更高版本
- 网络连接（局域网或互联网）

### 4.2 安装步骤

1. 传输 APK 到 Android 设备
2. 允许安装未知来源应用
3. 安装 APK
4. 打开应用

### 4.3 配置步骤

1. 在"配置"标签页输入 Gateway URL
2. Token 已内置，无需修改
3. 点击"连接"按钮
4. 切换到"会话"标签页开始对话

---

## 五、已知问题

### 5.1 Gateway 消息推送

**现象:** APP 发送消息成功，但可能收不到 Agent 的回复

**原因:** Gateway 需要实现 WebSocket 客户端消息路由机制

**临时方案:** 使用 HTTP 轮询或等待 Gateway 更新

### 5.2 Windows 平台警告

构建时出现的 `shared_preferences_windows` 和 `url_launcher_windows` 警告可忽略，不影响 Android 功能。

---

## 六、后续计划

- [ ] 自动重连机制
- [ ] 消息推送优化
- [ ] 多 Gateway 支持
- [ ] 消息历史同步
- [ ] 深色模式切换

---

## 七、联系方式

如有问题或建议，请联系 OpenClaw 开发团队。

---

**文档版本:** 1.0  
**最后更新:** 2026-03-20

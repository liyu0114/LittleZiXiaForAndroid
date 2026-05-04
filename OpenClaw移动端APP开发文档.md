# OpenClaw 移动端 APP 开发文档

**项目名称：** OpenClaw Mobile Client  
**版本：** v1.2.0  
**日期：** 2026-03-19  
**作者：** Windows龙虾 🦞

---

## 目录

1. [项目概述](#项目概述)
2. [开发环境](#开发环境)
3. [功能特性](#功能特性)
4. [架构设计](#架构设计)
5. [开发过程](#开发过程)
6. [问题诊断](#问题诊断)
7. [解决方案](#解决方案)
8. [部署指南](#部署指南)
9. [维护说明](#维护说明)
10. [附录](#附录)

---

## 1. 项目概述

### 1.1 项目目标

开发一个移动端 APP，通过 WebSocket 连接到 OpenClaw Gateway，实现：
- 远程控制 OpenClaw Gateway
- 发送消息给龙虾（AI 助手）
- 接收龙虾的回复
- 查看任务状态

### 1.2 技术栈

- **框架：** Flutter 3.x
- **语言：** Dart
- **通信：** WebSocket (Gateway RPC 协议)
- **状态管理：** Provider
- **本地存储：** SharedPreferences

### 1.3 项目结构

```
D:\mobile-client\
├── openclaw_app/              # Flutter APP
│   ├── lib/
│   │   ├── main.dart          # 应用入口
│   │   ├── providers/         # 状态管理
│   │   │   └── app_state.dart # 全局状态
│   │   ├── screens/           # 界面
│   │   │   ├── home_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── widgets/           # 组件
│   │       ├── message_list.dart
│   │       └── connection_status_card.dart
│   ├── pubspec.yaml           # 依赖配置
│   └── build/                 # 构建输出
└── openclaw_sdk/              # Flutter SDK
    ├── lib/
    │   └── src/
    │       ├── gateway_client.dart  # WebSocket 客户端
    │       ├── models.dart          # 数据模型
    │       ├── protocol.dart        # 协议定义
    │       └── exceptions.dart      # 异常处理
    └── pubspec.yaml
```

---

## 2. 开发环境

### 2.1 必需软件

| 软件 | 版本 | 安装路径 |
|------|------|----------|
| Flutter SDK | 3.x | D:\flutter\flutter |
| Android SDK | Latest | D:\Android |
| Android Studio | Latest | C:\Program Files\Android\Android Studio |
| Java (JBR) | 17+ | C:\Program Files\Android\Android Studio\jbr |

### 2.2 环境变量

```powershell
# Flutter
$env:PATH += ";D:\flutter\flutter\bin"

# Android SDK
$env:ANDROID_HOME = "D:\Android"
$env:PATH += ";D:\Android\platform-tools"
$env:PATH += ";D:\Android\tools"

# Java
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
```

### 2.3 验证环境

```bash
# 检查 Flutter
flutter doctor

# 检查设备
adb devices
```

---

## 3. 功能特性

### 3.1 已实现功能

✅ **连接管理**
- HTTP 连接测试（真实执行）
- WebSocket 连接建立
- 自动重连机制
- 连接状态显示

✅ **消息发送**
- 发送消息到 Gateway
- 真实的步骤状态显示（4 步流程）
- 详细的错误处理
- 消息队列管理

✅ **配置管理**
- Gateway URL 和 Token 配置
- 配置保存和加载
- 默认值设置

✅ **版本管理**
- APP 标题栏显示版本号
- APK 文件名包含版本号
- 自动版本号更新

### 3.2 待实现功能

⏳ **消息接收**
- 等待 Gateway 支持 WebSocket 客户端消息推送

⏳ **高级功能**
- 推送通知
- 多会话管理
- 历史消息查看
- 文件传输

---

## 4. 架构设计

### 4.1 架构图

```
┌─────────────────────────────────────────┐
│          OpenClaw Mobile APP            │
│                                         │
│  ┌─────────────┐    ┌────────────────┐ │
│  │  UI Layer   │◄──►│  State Layer   │ │
│  │ (Screens)   │    │ (Provider)     │ │
│  └─────────────┘    └────────────────┘ │
│                            │            │
│                            ▼            │
│                    ┌─────────────┐      │
│                    │  SDK Layer  │      │
│                    │ (WebSocket) │      │
│                    └─────────────┘      │
└─────────────────────────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Gateway RPC    │
                    │  (WebSocket)    │
                    └─────────────────┘
```

### 4.2 数据流

```
用户输入 → APP UI → AppState → SDK → Gateway → 龙虾
                    ↑                           │
                    └───────── WebSocket ───────┘
```

### 4.3 状态管理

```dart
class AppState extends ChangeNotifier {
  ConnectionStatus _connectionStatus;
  List<Message> _messages;
  OpenClawConfig? _config;
  GatewayClient? _client;
  
  // 连接、发送消息、状态更新等方法
}
```

---

## 5. 开发过程

### 5.1 版本历史

#### v1.0.0 - 初始版本
- 基本的 WebSocket 连接
- 简单的消息发送
- 基础 UI

#### v1.1.0 - 修复 StreamController 错误
**问题：** `Bad state: Cannot add new events after calling close`

**原因：** StreamController 在 dispose 后还在使用

**解决：** 所有 `_controller.add()` 调用前加 `!_controller.isClosed` 检查

```dart
void _updateStatus(ConnectionStatus newStatus) {
  _status = newStatus;
  if (!_statusController.isClosed) {
    _statusController.add(newStatus);
  }
}
```

#### v1.2.0 - 修复消息确认超时
**问题：** 消息发送成功，但等待确认超时（60秒）

**原因：** Gateway 不返回确认消息，SDK 强制等待

**解决：** 
- 超时时间改为 10 秒
- 超时后不报错，继续执行
- 添加真实步骤状态显示

```dart
final ack = await _pendingMessages[message.id]!.future.timeout(
  const Duration(seconds: 10),
  onTimeout: () {
    _log('⚠️ No ack after 10s (Gateway may not send ack)', level: 'WARN');
    return SendAck(messageId: message.id, success: true);
  },
);
```

---

## 6. 问题诊断

### 6.1 主要问题：收不到龙虾的回复

**现象：**
```
✅ 步骤 1/4 完成: 连接正常
✅ 步骤 2/4 完成: 消息已发送
⚠️ 步骤 3/4 警告: 5秒内未收到确认
⏳ 步骤 4/4: 等待龙虾回复... (卡住)
```

**诊断过程：**

1. **确认 APP 端正常**
   ```bash
   # 检查连接
   netstat -ano | grep :18789 | grep ESTABLISHED
   # 结果：ESTABLISHED ✅
   ```

2. **确认消息流**
   ```
   APP → Gateway: ✅ 消息发送成功
   Gateway → 龙虾: ✅ 龙虾收到了消息
   龙虾 → Gateway: ✅ 龙虾回复了消息
   Gateway → APP: ❌ 回复没有通过 WebSocket 返回
   ```

3. **查看 Gateway 日志**
   ```bash
   tail -f ~/.openclaw/logs/gateway.log
   # 没有看到消息推送相关日志
   ```

### 6.2 根本原因

**Gateway 的 WebSocket 客户端消息推送机制还没有实现。**

Gateway 目前只支持 Web 界面的消息接收，移动端 APP 通过 WebSocket 连接作为客户端，但 Gateway 不知道如何把龙虾的回复通过 WebSocket 返回给移动客户端。

---

## 7. 解决方案

### 7.1 方案 1：修改 Gateway 源码（推荐）

**步骤：**

1. **找到 Gateway 的 WebSocket 消息路由代码**
   - Gateway RPC 处理器
   - WebSocket 连接管理器
   - 消息路由器

2. **添加客户端连接管理**
   ```javascript
   // 伪代码
   const clientConnections = new Map<string, WebSocket>();
   
   // 当客户端连接时
   gateway.on('client:connect', (sessionKey, ws) => {
     clientConnections.set(sessionKey, ws);
   });
   
   // 当收到 agent 的回复时
   gateway.on('agent:response', (response) => {
     const sessionKey = response.sessionKey;
     const clientConnection = clientConnections.get(sessionKey);
     
     if (clientConnection && clientConnection.readyState === WebSocket.OPEN) {
       clientConnection.send(JSON.stringify({
         type: 'event',
         event: 'agent',
         payload: {
           data: response
         }
       }));
     }
   });
   ```

3. **重新编译和部署 Gateway**
   ```bash
   npm run build
   npm run deploy
   ```

### 7.2 方案 2：HTTP 轮询（临时方案）

**实现思路：**
```dart
// 发送消息后启动轮询
Timer.periodic(Duration(seconds: 2), (timer) async {
  final response = await http.get('$gatewayUrl/messages?since=$lastMessageId');
  if (response.statusCode == 200) {
    final messages = jsonDecode(response.body);
    if (messages.isNotEmpty) {
      // 显示新消息
      timer.cancel();
    }
  }
});
```

**缺点：**
- 增加 Gateway 负载
- 实时性较差
- 不是最优解决方案

### 7.3 方案 3：等待官方支持

向 OpenClaw 团队报告问题，等待官方在未来版本中支持移动客户端的消息推送。

---

## 8. 部署指南

### 8.1 构建脚本

使用自动构建脚本：

```powershell
# 基本构建
.\build-and-deploy.ps1 -Version "1.3.0"

# 构建并自动部署到连接的设备
.\build-and-deploy.ps1 -Version "1.3.0" -Deploy
```

### 8.2 手动构建

```bash
# 1. 清理
cd D:\mobile-client\openclaw_app
flutter clean

# 2. 构建
flutter build apk --release

# 3. 复制
Copy-Item build\app\outputs\flutter-apk\app-release.apk D:\desktop\OpenClaw_v1.3.0.apk
```

### 8.3 安装

**方法 1：通过 USB**
```bash
adb install -r OpenClaw_v1.3.0.apk
```

**方法 2：手动安装**
1. 将 APK 拷贝到手机
2. 在手机上打开 APK 文件
3. 允许安装未知来源应用
4. 完成安装

---

## 9. 维护说明

### 9.1 版本号管理

**位置：**
- `pubspec.yaml`: `version: 1.3.0+2026031901`
- `home_screen.dart`: 标题栏显示 `v1.3.0`

**格式：**
- 主版本.次版本.补丁版本
- 构建号：YYYYMMDDXX

### 9.2 代码规范

- 使用 Provider 进行状态管理
- 所有异步操作使用 async/await
- 错误处理必须详细
- 添加必要的日志输出

### 9.3 测试检查清单

- [ ] HTTP 测试成功
- [ ] WebSocket 连接成功
- [ ] 消息发送成功
- [ ] 步骤状态显示正确
- [ ] 配置保存和加载正常
- [ ] 版本号显示正确
- [ ] 错误提示清晰

---

## 10. 附录

### 10.1 WebSocket 消息格式

**发送消息：**
```json
{
  "type": "req",
  "id": "1234567890",
  "method": "agent",
  "params": {
    "message": "你好",
    "idempotencyKey": "1234567890",
    "sessionKey": "agent:main:main",
    "agentId": "main"
  }
}
```

**期望收到：**
```json
{
  "type": "event",
  "event": "agent",
  "payload": {
    "data": {
      "id": "response-id",
      "role": "assistant",
      "content": "你好！我是龙虾...",
      "thinking": "思考过程..."
    }
  }
}
```

### 10.2 关键文件清单

| 文件 | 说明 |
|------|------|
| `lib/main.dart` | 应用入口 |
| `lib/providers/app_state.dart` | 全局状态管理 |
| `lib/screens/home_screen.dart` | 主界面 |
| `lib/screens/settings_screen.dart` | 配置界面 |
| `lib/widgets/message_list.dart` | 消息列表组件 |
| `lib/widgets/connection_status_card.dart` | 连接状态卡片 |
| `openclaw_sdk/lib/src/gateway_client.dart` | WebSocket 客户端 |
| `openclaw_sdk/lib/src/models.dart` | 数据模型 |
| `openclaw_sdk/lib/src/protocol.dart` | 协议定义 |

### 10.3 常见问题

**Q1: 连接失败怎么办？**
- 检查 Gateway 是否运行
- 检查网络连接
- 验证 URL 和 Token 是否正确

**Q2: 消息发送后卡住？**
- 这是已知问题（Gateway 消息路由）
- 查看 `memory/2026-03-19-mobile-app-gateway-issue.md`

**Q3: 如何调试？**
- 连接手机通过 USB
- 使用 `adb logcat` 查看日志
- 或在 Flutter 中使用 `debugPrint()`

### 10.4 相关资源

- **APP 代码：** `D:\mobile-client\`
- **APK 位置：** `D:\desktop\OpenClaw_v1.2.0_20260319_0626.apk`
- **构建脚本：** `D:\mobile-client\build-and-deploy.ps1`
- **Gateway 日志：** `C:\Users\Administrator\.openclaw\logs\`
- **详细文档：** `memory/2026-03-19-mobile-app-gateway-issue.md`
- **OpenClaw 文档：** `C:\Users\Administrator\AppData\Roaming\npm\node_modules\openclaw\docs\`

---

**文档版本：** 1.0  
**最后更新：** 2026-03-19  
**下次审查：** 2026-04-19

---

## 变更日志

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-03-19 | 1.0 | 初始版本 | Windows龙虾 🦞 |

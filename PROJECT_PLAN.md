# OpenClaw 移动端客户端开发计划

## 项目目标
开发 OpenClaw 移动端客户端，作为远程遥控器控制 Gateway。

## 目标平台
1. **Windows 开发环境** → 华为手机客户端
2. **Mac 开发环境** → iOS 客户端

## 技术方案

### 方案 A: Flutter（推荐）
- **优点**: 一套代码支持 Android/iOS/HarmonyOS，开发效率高
- **环境**: Windows 可开发 Android 版，Mac 可开发 iOS 版
- **三种产品模式**:
  1. **SDK**: Flutter package (Dart 库)
  2. **Plugin**: Flutter plugin (原生桥接)
  3. **App**: 完整 Flutter 应用

### 方案 B: 原生开发
- **华为手机**: Android (Kotlin) 或 HarmonyOS (ArkTS)
- **iOS**: Swift/SwiftUI
- **三种产品模式**:
  1. **动态链接库**: .aar (Android) / .framework (iOS)
  2. **插件**: 系统插件或扩展
  3. **App**: 完整原生应用

## 推荐方案: Flutter
理由:
1. 代码复用率高（Android + iOS + HarmonyOS）
2. Windows 和 Mac 都能开发
3. 热重载开发效率高
4. 三种产品模式都支持良好

## 项目结构
```
openclaw-mobile/
├── packages/
│   ├── openclaw_sdk/          # SDK 模式
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── gateway_client.dart
│   │   │   │   ├── models.dart
│   │   │   │   └── protocol.dart
│   │   │   └── openclaw_sdk.dart
│   │   └── pubspec.yaml
│   │
│   ├── openclaw_plugin/       # Plugin 模式
│   │   ├── lib/
│   │   ├── android/
│   │   ├── ios/
│   │   └── pubspec.yaml
│   │
│   └── openclaw_app/          # 完整 App
│       ├── lib/
│       │   ├── main.dart
│       │   ├── screens/
│       │   ├── widgets/
│       │   └── services/
│       ├── android/
│       ├── ios/
│       └── pubspec.yaml
│
├── melos.yaml                 # Monorepo 管理
└── README.md
```

## 核心功能
1. **Gateway 连接管理**
   - WebSocket 连接
   - 自动重连
   - 心跳保活

2. **消息推送接收**
   - 实时消息
   - 通知显示
   - 消息历史

3. **远程控制**
   - 查看 Gateway 状态
   - 发送命令
   - 管理会话

4. **用户界面**
   - Dashboard
   - 消息列表
   - 设置页面

## 开发阶段

### Phase 1: SDK 开发 (1-2 周)
- [ ] Gateway WebSocket 协议实现
- [ ] 消息模型定义
- [ ] 认证机制
- [ ] 错误处理

### Phase 2: Plugin 开发 (1 周)
- [ ] Android 原生桥接
- [ ] iOS 原生桥接
- [ ] 通知集成
- [ ] 后台服务

### Phase 3: App 开发 (2-3 周)
- [ ] UI 设计
- [ ] 页面实现
- [ ] 状态管理
- [ ] 测试

### Phase 4: 测试与发布 (1 周)
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能优化
- [ ] 打包发布

## 当前任务
1. 在 Windows 安装 Flutter SDK
2. 配置 Android 开发环境
3. 创建项目结构
4. 开始 SDK 开发

## 验证方案
使用 subagent 进行代码审查和测试验证。

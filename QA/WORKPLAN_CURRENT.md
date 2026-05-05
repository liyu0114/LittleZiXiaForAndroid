# 小紫霞项目工作计划

**最后更新:** 2026-03-29 18:35
**状态:** 执行中

---

## 当前任务

### 分布式小紫霞网络 - UI 集成

**需求编号:** REQ_20260329_1800
**优先级:** P0
**状态:** 开发中
**预计工时:** 6小时

---

## 背景

### 已完成功能（26小时）

| 任务 | 工时 | 状态 |
|------|------|------|
| 话题管理系统 P0 | 8h | ✅ 完成 |
| 执行力增强计划 P0 | 6h | ✅ 完成 |
| Gateway 连接管理 | 4h | ✅ 完成 |
| 分布式网络 P0（代码）| 8h | ✅ 完成（已存在）|

### 重复代码已删除

删除了 1795 行重复代码：
- `p2p_node_manager.dart`
- `gateway_connection_manager.dart`
- `p2p_connection_screen.dart`
- `gateway_connection_screen.dart`
- `gateway_config.dart`

使用已有实现：
- `multi_device_service.dart` - WiFi Direct + 蓝牙 Mesh + P2P
- `remote_connection.dart` - Gateway 连接 + Token 认证
- `qrcode_service.dart` - 二维码生成/扫描

---

## 当前开发任务（6小时）

### 1. 创建协作界面（4h）

**文件:** `lib/screens/collaboration_screen.dart`

**功能:**

```
协作界面
├── Server 模式
│   ├── 显示本机 IP:Port
│   ├── 生成二维码（供其他设备扫描）
│   └── 显示已连接设备列表
├── Client 模式
│   ├── 扫描二维码连接
│   ├── 手动输入 IP:Port
│   └── 连接状态显示
└── Gateway 模式
    ├── 输入 Gateway URL
    ├── 输入 Token
    └── 连接状态显示
```

**集成服务:**
- `MultiDeviceCollaborationService` - P2P 组网
- `RemoteConnection` - Gateway 连接
- `QRCodeService` - 二维码

---

### 2. AppState 集成（1h）

**修改文件:** `lib/providers/app_state.dart`

**新增:**
```dart
class AppState extends ChangeNotifier {
  late MultiDeviceCollaborationService _collabService;
  late RemoteConnection _remoteConnection;
  late QRCodeService _qrcodeService;

  // Getters
  MultiDeviceCollaborationService get collabService => _collabService;
  RemoteConnection get remoteConnection => _remoteConnection;
  QRCodeService get qrcodeService => _qrcodeService;

  Future<void> initializeCollaboration() async {
    await _collabService.initialize();
  }
}
```

---

### 3. 测试（1h）

**测试项目:**
1. 两台手机 P2P 连接测试
2. 二维码扫描连接测试
3. Gateway 连接测试
4. 消息广播测试

---

## 技术实现

### multi_device_service.dart

**已实现能力:**
- WiFi Direct P2P（Nearby Connections）
- 蓝牙 Mesh（FlutterBluePlus）
- 设备角色切换（leader/worker/observer）
- 设备发现和连接
- 消息广播
- 任务分配

### remote_connection.dart

**已实现能力:**
- WebSocket 连接
- Token 认证
- 执行远程技能
- 会话管理
- 发送命令

### qrcode_service.dart

**已实现能力:**
- 二维码生成（qr_flutter）
- 二维码扫描（mobile_scanner）

---

## 依赖

```yaml
dependencies:
  web_socket_channel: ^2.4.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.2
  connectivity_plus: ^6.0.5
  flutter_blue_plus: ^1.32.0
  nearby_connections: ^4.1.0
```

---

## 下一步

1. 创建 `collaboration_screen.dart`
2. 集成到 `AppState`
3. 添加到导航菜单
4. 测试

---

## 铁律

**开发前必须检查:** `QA/IMPLEMENTED_FEATURES.md`

**Liyu 指示:**
- 有了，需要增强 → 增强
- 没有 → 增加
- 已有且超越预期 → 保留

---

## 角色分工

- **程序员:** 编码实现，听从质检员指挥
- **质检员:** 需求分析、代码审查、研究 OpenClaw
- **Liyu:** 老板，最终决策者

---

**告知所有合作者:** 工作计划已确定，正在执行中。

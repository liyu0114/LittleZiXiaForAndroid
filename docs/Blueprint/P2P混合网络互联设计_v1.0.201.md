# P2P混合网络互联设计 v1.0.201（更新版）

> **版本**: v1.0.201
> **更新**: 2026-05-05
> **状态**: 讨论稿

---

## 一、目标

- 应用层网络透明（不用关心底层网络）
- 混合组网（不同房间、不同网络）
- 异构设备（iOS/Android/华为/电脑）
- **所有设备加入同一个群聊，协作执行任务**

---

## 二、架构

```
┌────────────────────────────────────────────────────┐
│              应用层：任务协作群                    │
│  ┌────────────────────────────────────────────┐ │
│  │ • 消息channel（群聊）                      │ │
│  │ • TaskDispatcher                           │ │
│  │ • 任务广播/抢接/结果回传                   │ │
│  └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
                      ↓
┌────────────────────────────────────────────────────┐
│              网络层（透明）                       │
│  ┌────────────────────────────────────────────┐ │
│  │ NetworkRouter                              │ │
│  │ • 局域网/Tailscale/中继混搭               │ │
│  │ • 自动选最优路径                          │ │
│  └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

---

## 三、核心设计

### 3.1 统一网络接口

```dart
abstract class NetworkInterface {
  Future<void> send(Device target, Message msg);
  Stream<Message> receive(Device from);
  Future<bool> isReachable(Device target);
  Future<int> ping(Device target);
}
```

### 3.2 网络层实现

```dart
// 局域网（同WiFi，最快）
class LanNetwork extends NetworkInterface {
  // UDP广播发现 + TCP传输
}

// Tailscale（跨网络）
class TailscaleNetwork extends NetworkInterface {
  // 通过tail0连接
}

// 中继（离线备选）
class RelayNetwork extends NetworkInterface {
  // 服务器中转
}
```

### 3.3 路由管理（核心）

```dart
class NetworkRouter {
  // 自动选择最优路径
  Future<NetworkInterface> getBestRoute(Device target) async {
    // 1. 局域网优先（同WiFi最快）
    if (await lan.isReachable(target)) return lan;
    
    // 2. Tailscale次之（跨网络）
    if (await tailscale.isReachable(target)) return tailscale;
    
    // 3. 中继保底
    return relay;
  }
}
```

### 3.4 设备管理

```dart
class DeviceRegistry {
  // 设备注册表
  Map<String, Device> devices = {};
  
  // 发现设备
  Future<List<Device>> discover() async {
    // WiFi发现
    // Tailscale peers
    // 手动配对
  }
}
```

---

## 四、群聊任务协作

### 4.1 设计目标

```
所有联网设备
    ↓
加入同一个群聊（应用层透明）
    ↓
每个设备从群聊领取任务
    ↓
各设备独立执行
    ↓
结果回传群聊
```

### 4.2 任务流程

```
1. 用户在群聊发任务
       ↓
2. TaskDispatcher收到
       ↓
3. 广播到所有在线设备
       ↓
4. 设备A抢接（手快）
       ↓
5. 设备A执行任务
       ↓
6. 结果回传群聊
       ↓
7. 群聊显示结果
```

### 4.3 消息格式

```dart
// 群聊消息
class GroupMessage {
  MessageType type;  // task_broadcast/task_claim/task_result
  Task? task;
  String deviceId;
  String? result;
}

// 设备不需要知道其他设备怎么连上的
// 只需要知道"我在群聊中，群里有其他设备"
```

### 4.4 设备管理（在群聊中）

```dart
class GroupChatDeviceManager {
  // 所有在线设备
  List<Device> get onlineDevices;
  
  // 设备状态
  DeviceStatus getStatus(String deviceId);
  
  // 广播任务（所有设备可见）
  Future<String> broadcastTask(Task task);
  
  // 设备抢接
  Future<String> claimTask(String taskId, String deviceId);
}
```

---

## 五、示例场景

### 场景：房间A和房间B

```
房间A（WiFi-A）       房间B（WiFi-B）
+-----------+       +-----------+
| 手机A    │       | 手机D    │
| 电脑B    │       | 电脑E    │
| 华为C    │       | 苹果F    │
+-----------+       +-----------+
       ↓                   ↓
    ┌─────────────────────────┐
    │   Tailscale互联       │
    │   （跨房间）         │
    └─────────────────────────┘
           ↓
    ┌─────────────────────────┐
    │   群聊：任务协作       │
    │  设备A/B/C/D/E/F全互联  │
    │  任何设备可领任务       │
    └─────────────────────────┘
```

---

## 六、速度优先级

| 优先级 | 网络 | 延迟 |
|--------|------|------|
| 1 | 局域网UDP | <1ms |
| 2 | 局域网TCP | <5ms |
| 3 | Tailscale | 20-50ms |
| 4 | 中继 | 100ms+ |

---

*版本: v1.0.201*
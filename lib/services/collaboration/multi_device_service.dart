/// 多设备协作服务
/// 
/// 实现移动设备之间的协作：
/// - 蓝牙 Mesh 网络
/// - WiFi Direct
/// - 云端中继（通过 Gateway）
/// - P2P 连接

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// 设备信息
class DeviceInfo {
  final String id;
  final String name;
  final String platform; // 'android', 'ios', 'macos', 'windows'
  final String role; // 'leader', 'worker', 'observer'
  final DateTime connectedAt;
  final Map<String, dynamic> capabilities;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.role,
    required this.connectedAt,
    this.capabilities = const {},
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'],
      name: json['name'],
      platform: json['platform'],
      role: json['role'],
      connectedAt: DateTime.parse(json['connectedAt']),
      capabilities: json['capabilities'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'role': role,
    'connectedAt': connectedAt.toIso8601String(),
    'capabilities': capabilities,
  };
}

/// 协作任务
class CollaborationTask {
  final String id;
  final String type; // 'parallel', 'sequential', 'distributed'
  final String description;
  final String? assignedTo;
  final String status; // 'pending', 'running', 'completed', 'failed'
  final Map<String, dynamic> params;
  final Map<String, dynamic>? result;
  final DateTime createdAt;
  final DateTime? completedAt;

  CollaborationTask({
    required this.id,
    required this.type,
    required this.description,
    this.assignedTo,
    required this.status,
    required this.params,
    this.result,
    required this.createdAt,
    this.completedAt,
  });

  factory CollaborationTask.fromJson(Map<String, dynamic> json) {
    return CollaborationTask(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      assignedTo: json['assignedTo'],
      status: json['status'],
      params: json['params'] ?? {},
      result: json['result'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'description': description,
    'assignedTo': assignedTo,
    'status': status,
    'params': params,
    'result': result,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };
}

/// 多设备协作服务
class MultiDeviceCollaborationService extends ChangeNotifier {
  // 本设备信息
  DeviceInfo? _localDevice;
  
  // 已连接的设备
  final Map<String, DeviceInfo> _connectedDevices = {};
  
  // 协作任务
  final Map<String, CollaborationTask> _tasks = {};
  
  // 本设备角色
  String _role = 'worker'; // 'leader', 'worker', 'observer'
  
  // 连接状态
  bool _isScanning = false;
  bool _isAdvertising = false;
  
  // 通信通道
  StreamSubscription? _dataSubscription;
  
  // Getters
  DeviceInfo? get localDevice => _localDevice;
  List<DeviceInfo> get connectedDevices => _connectedDevices.values.toList();
  List<CollaborationTask> get activeTasks => 
      _tasks.values.where((t) => t.status == 'running').toList();
  String get role => _role;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  bool get isLeader => _role == 'leader';
  
  /// 初始化
  Future<void> initialize() async {
    debugPrint('[Collaboration] 初始化多设备协作服务');
    
    // 检测蓝牙支持
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('[Collaboration] 蓝牙不支持');
      return;
    }
    
    // 获取本设备信息
    _localDevice = DeviceInfo(
      id: await _getDeviceId(),
      name: await _getDeviceName(),
      platform: defaultTargetPlatform.name,
      role: _role,
      connectedAt: DateTime.now(),
    );
    
    debugPrint('[Collaboration] 本设备: ${_localDevice!.name} (${_localDevice!.id})');
  }
  
  /// 获取设备 ID
  Future<String> _getDeviceId() async {
    // 使用设备唯一标识
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// 获取设备名称
  Future<String> _getDeviceName() async {
    return '小紫霞设备';
  }
  
  /// 设置角色
  Future<void> setRole(String newRole) async {
    _role = newRole;
    _localDevice = _localDevice?.copyWith(role: newRole);
    notifyListeners();
    debugPrint('[Collaboration] 角色切换为: $newRole');
  }
  
  /// 开始广播（让其他设备发现）
  Future<void> startAdvertising({
    String? serviceName,
    Map<String, dynamic>? capabilities,
  }) async {
    if (_isAdvertising) return;
    
    try {
      // 使用 Nearby Connections 广播
      await NearbyConnections().startAdvertising(
        serviceName ?? 'LittleZiXia',
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (clientId, userInfo) {
          debugPrint('[Collaboration] 连接请求: $clientId');
          _onConnectionInitiated(clientId, userInfo);
        },
        onConnectionResult: (clientId, status) {
          debugPrint('[Collaboration] 连接结果: $clientId - $status');
          _onConnectionResult(clientId, status);
        },
        onDisconnected: (clientId) {
          debugPrint('[Collaboration] 断开连接: $clientId');
          _onDisconnected(clientId);
        },
      );
      
      _isAdvertising = true;
      notifyListeners();
      debugPrint('[Collaboration] 开始广播');
    } catch (e) {
      debugPrint('[Collaboration] 广播失败: $e');
    }
  }
  
  /// 停止广播
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    await NearbyConnections().stopAdvertising();
    _isAdvertising = false;
    notifyListeners();
    debugPrint('[Collaboration] 停止广播');
  }
  
  /// 扫描设备
  Future<void> startDiscovery() async {
    if (_isScanning) return;
    
    try {
      await NearbyConnections().startDiscovery(
        'LittleZiXia',
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('[Collaboration] 发现设备: $endpointName ($endpointId)');
          _onEndpointFound(endpointId, endpointName, serviceId);
        },
        onEndpointLost: (endpointId) {
          debugPrint('[Collaboration] 设备丢失: $endpointId');
          _onEndpointLost(endpointId);
        },
      );
      
      _isScanning = true;
      notifyListeners();
      debugPrint('[Collaboration] 开始扫描');
    } catch (e) {
      debugPrint('[Collaboration] 扫描失败: $e');
    }
  }
  
  /// 停止扫描
  Future<void> stopDiscovery() async {
    if (!_isScanning) return;
    
    await NearbyConnections().stopDiscovery();
    _isScanning = false;
    notifyListeners();
    debugPrint('[Collaboration] 停止扫描');
  }
  
  /// 连接设备
  Future<void> connectToDevice(String endpointId) async {
    try {
      await NearbyConnections().requestConnection(
        _localDevice!.name,
        endpointId,
        onConnectionInitiated: (clientId, userInfo) {
          _onConnectionInitiated(clientId, userInfo);
        },
        onConnectionResult: (clientId, status) {
          _onConnectionResult(clientId, status);
        },
        onDisconnected: (clientId) {
          _onDisconnected(clientId);
        },
      );
      debugPrint('[Collaboration] 请求连接: $endpointId');
    } catch (e) {
      debugPrint('[Collaboration] 连接失败: $e');
    }
  }
  
  /// 接受连接
  Future<void> acceptConnection(String endpointId) async {
    try {
      await NearbyConnections().acceptConnection(
        endpointId,
        onPayLoadRecieved: (endpointId, payload) {
          _onPayloadReceived(endpointId, payload);
        },
      );
      debugPrint('[Collaboration] 接受连接: $endpointId');
    } catch (e) {
      debugPrint('[Collaboration] 接受连接失败: $e');
    }
  }
  
  /// 发送消息
  Future<void> sendMessage(String endpointId, Map<String, dynamic> message) async {
    try {
      final payload = Payload(
        id: DateTime.now().millisecondsSinceEpoch,
        data: Uint8List.fromList(utf8.encode(jsonEncode(message))),
      );
      
      await NearbyConnections().sendPayload(endpointId, payload);
      debugPrint('[Collaboration] 发送消息到 $endpointId');
    } catch (e) {
      debugPrint('[Collaboration] 发送消息失败: $e');
    }
  }
  
  /// 广播消息（所有设备）
  Future<void> broadcastMessage(Map<String, dynamic> message) async {
    for (final device in _connectedDevices.keys) {
      await sendMessage(device, message);
    }
  }
  
  /// 分配任务
  Future<void> assignTask(String deviceId, CollaborationTask task) async {
    if (!isLeader) {
      debugPrint('[Collaboration] 只有 leader 可以分配任务');
      return;
    }
    
    _tasks[task.id] = task;
    
    // 发送任务到指定设备
    await sendMessage(deviceId, {
      'type': 'task_assigned',
      'task': task.toJson(),
    });
    
    notifyListeners();
    debugPrint('[Collaboration] 任务已分配: ${task.id} -> $deviceId');
  }
  
  /// 更新任务状态
  Future<void> updateTaskStatus(String taskId, String status, {Map<String, dynamic>? result}) async {
    final task = _tasks[taskId];
    if (task == null) return;
    
    _tasks[taskId] = CollaborationTask(
      id: task.id,
      type: task.type,
      description: task.description,
      assignedTo: task.assignedTo,
      status: status,
      params: task.params,
      result: result ?? task.result,
      createdAt: task.createdAt,
      completedAt: status == 'completed' ? DateTime.now() : null,
    );
    
    // 通知 leader
    if (status == 'completed' && !isLeader && _localDevice != null) {
      await broadcastMessage({
        'type': 'task_completed',
        'taskId': taskId,
        'result': result,
      });
    }
    
    notifyListeners();
    debugPrint('[Collaboration] 任务状态更新: $taskId -> $status');
  }
  
  // 事件处理
  void _onConnectionInitiated(String clientId, Map<String, dynamic> userInfo) {
    debugPrint('[Collaboration] 连接初始化: $clientId, $userInfo');
  }
  
  void _onConnectionResult(String clientId, String status) {
    if (status == 'CONNECTED') {
      debugPrint('[Collaboration] 连接成功: $clientId');
      acceptConnection(clientId);
    } else {
      debugPrint('[Collaboration] 连接被拒绝: $clientId');
    }
  }
  
  void _onDisconnected(String clientId) {
    _connectedDevices.remove(clientId);
    notifyListeners();
  }
  
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    final device = DeviceInfo(
      id: endpointId,
      name: endpointName,
      platform: 'unknown',
      role: 'worker',
      connectedAt: DateTime.now(),
    );
    
    _connectedDevices[endpointId] = device;
    notifyListeners();
  }
  
  void _onEndpointLost(String endpointId) {
    _connectedDevices.remove(endpointId);
    notifyListeners();
  }
  
  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      final message = jsonDecode(utf8.decode(payload.data!)) as Map<String, dynamic>;
      debugPrint('[Collaboration] 收到消息: $message');
      
      _handleMessage(endpointId, message);
    } catch (e) {
      debugPrint('[Collaboration] 解析消息失败: $e');
    }
  }
  
  /// 处理消息
  void _handleMessage(String endpointId, Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    switch (type) {
      case 'task_assigned':
        final task = CollaborationTask.fromJson(message['task']);
        _tasks[task.id] = task;
        notifyListeners();
        debugPrint('[Collaboration] 收到任务: ${task.description}');
        break;
        
      case 'task_completed':
        final taskId = message['taskId'] as String;
        final result = message['result'] as Map<String, dynamic>?;
        updateTaskStatus(taskId, 'completed', result: result);
        break;
        
      case 'ping':
        sendMessage(endpointId, {'type': 'pong'});
        break;
        
      case 'sync_request':
        // 同步所有任务和设备信息
        _sendSyncResponse(endpointId);
        break;
    }
  }
  
  /// 发送同步响应
  Future<void> _sendSyncResponse(String endpointId) async {
    await sendMessage(endpointId, {
      'type': 'sync_response',
      'devices': _connectedDevices.map((k, v) => MapEntry(k, v.toJson())),
      'tasks': _tasks.map((k, v) => MapEntry(k, v.toJson())),
    });
  }
  
  /// 获取协作统计
  Map<String, dynamic> get statistics {
    return {
      'connectedDevices': _connectedDevices.length,
      'activeTasks': activeTasks.length,
      'completedTasks': _tasks.values.where((t) => t.status == 'completed').length,
      'role': _role,
    };
  }
  
  /// 断开所有连接
  Future<void> disconnectAll() async {
    await stopAdvertising();
    await stopDiscovery();
    
    for (final deviceId in _connectedDevices.keys) {
      try {
        await NearbyConnections().disconnectFromEndpoint(deviceId);
      } catch (e) {
        debugPrint('[Collaboration] 断开连接失败: $e');
      }
    }
    
    _connectedDevices.clear();
    notifyListeners();
    debugPrint('[Collaboration] 已断开所有连接');
  }
  
  @override
  void dispose() {
    disconnectAll();
    _dataSubscription?.cancel();
    super.dispose();
  }
}

// DeviceInfo copyWith 辅助方法
extension DeviceInfoExtension on DeviceInfo {
  DeviceInfo copyWith({
    String? id,
    String? name,
    String? platform,
    String? role,
    DateTime? connectedAt,
    Map<String, dynamic>? capabilities,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      role: role ?? this.role,
      connectedAt: connectedAt ?? this.connectedAt,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

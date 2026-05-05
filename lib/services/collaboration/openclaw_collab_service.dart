/// OpenClaw 协作服务
/// 
/// 实现移动设备与桌面 OpenClaw 的协作：
/// - 通过 Gateway WebSocket 连接
/// - 共享上下文和记忆
/// - 任务分配和结果同步
/// - 远程工具调用

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../remote/remote_connection.dart';
import '../memory/memory_service.dart';

/// 协作模式
enum CollaborationMode {
  standalone,    // 独立模式
  node,          // Node 模式（连接到 Gateway）
  hybrid,        // 混合模式
}

/// 远程 OpenClaw 状态
class OpenClawStatus {
  final bool isOnline;
  final String? version;
  final String? platform;
  final int activeSessions;
  final int availableTools;
  final DateTime? lastSync;

  OpenClawStatus({
    required this.isOnline,
    this.version,
    this.platform,
    this.activeSessions = 0,
    this.availableTools = 0,
    this.lastSync,
  });

  factory OpenClawStatus.fromJson(Map<String, dynamic> json) {
    return OpenClawStatus(
      isOnline: json['isOnline'] ?? false,
      version: json['version'],
      platform: json['platform'],
      activeSessions: json['activeSessions'] ?? 0,
      availableTools: json['availableTools'] ?? 0,
      lastSync: json['lastSync'] != null 
          ? DateTime.parse(json['lastSync']) 
          : null,
    );
  }
}

/// OpenClaw 协作服务
class OpenClawCollaborationService extends ChangeNotifier {
  // 连接
  RemoteConnection? _remoteConnection;
  WebSocketChannel? _channel;
  
  // 状态
  CollaborationMode _mode = CollaborationMode.standalone;
  OpenClawStatus? _openclawStatus;
  bool _isConnected = false;
  
  // 同步
  StreamSubscription? _syncSubscription;
  DateTime? _lastSyncTime;
  
  // 记忆服务
  MemoryService? _memoryService;
  
  // 任务队列
  final List<Map<String, dynamic>> _pendingTasks = [];
  final List<Map<String, dynamic>> _completedTasks = [];
  
  // Getters
  CollaborationMode get mode => _mode;
  OpenClawStatus? get openclawStatus => _openclawStatus;
  bool get isConnected => _isConnected;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<Map<String, dynamic>> get pendingTasks => List.unmodifiable(_pendingTasks);
  List<Map<String, dynamic>> get completedTasks => List.unmodifiable(_completedTasks);
  
  /// 初始化
  Future<void> initialize({
    MemoryService? memoryService,
  }) async {
    _memoryService = memoryService;
    debugPrint('[OpenClawCollab] 初始化协作服务，模式: $_mode');
  }
  
  /// 设置模式
  Future<void> setMode(CollaborationMode newMode) async {
    if (_mode == newMode) return;
    
    // 断开现有连接
    await disconnect();
    
    _mode = newMode;
    notifyListeners();
    
    // 如果是 Node 模式，尝试连接
    if (_mode == CollaborationMode.node || _mode == CollaborationMode.hybrid) {
      // 等待用户配置 Gateway
      debugPrint('[OpenClawCollab] 模式切换为 $newMode，等待连接 Gateway');
    }
  }
  
  /// 连接到 OpenClaw Gateway
  Future<bool> connect(String gatewayUrl, {String? token}) async {
    if (_isConnected) {
      debugPrint('[OpenClawCollab] 已连接，跳过');
      return true;
    }
    
    try {
      debugPrint('[OpenClawCollab] 连接到 Gateway: $gatewayUrl');
      
      // 创建 WebSocket 连接
      final uri = Uri.parse(gatewayUrl);
      _channel = WebSocketChannel.connect(uri);
      
      // 发送握手
      await _sendHandshake(token);
      
      // 监听消息
      _syncSubscription = _channel!.stream.listen(
        (data) => _onMessage(data),
        onError: (error) => _onError(error),
        onDone: () => _onDisconnect(),
      );
      
      _isConnected = true;
      _mode = CollaborationMode.node;
      notifyListeners();
      
      debugPrint('[OpenClawCollab] 连接成功');
      return true;
    } catch (e) {
      debugPrint('[OpenClawCollab] 连接失败: $e');
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    _syncSubscription?.cancel();
    _syncSubscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    _isConnected = false;
    _openclawStatus = null;
    notifyListeners();
    
    debugPrint('[OpenClawCollab] 已断开连接');
  }
  
  /// 发送握手
  Future<void> _sendHandshake(String? token) async {
    final handshake = {
      'type': 'req',
      'id': 'handshake_${DateTime.now().millisecondsSinceEpoch}',
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': 'little_zixia',
          'version': '1.0.42',
          'platform': defaultTargetPlatform.name,
          'mode': 'node',
        },
        'role': 'node',
        'scopes': ['node.read', 'node.write'],
        'caps': [
          'mobile.sensors',
          'mobile.location',
          'mobile.camera',
          'mobile.health',
        ],
        'commands': [
          'sensor.read',
          'location.get',
          'camera.snap',
          'health.sync',
        ],
        'permissions': {},
        'auth': token != null ? {'token': token} : null,
      },
    };
    
    _channel!.sink.add(jsonEncode(handshake));
    debugPrint('[OpenClawCollab] 握手已发送');
  }
  
  /// 发送消息
  Future<void> send(Map<String, dynamic> message) async {
    if (!_isConnected || _channel == null) {
      debugPrint('[OpenClawCollab] 未连接，无法发送');
      return;
    }
    
    _channel!.sink.add(jsonEncode(message));
  }
  
  /// 同步记忆
  Future<void> syncMemory() async {
    if (!_isConnected || _memoryService == null) {
      debugPrint('[OpenClawCollab] 无法同步记忆');
      return;
    }
    
    // 发送记忆同步请求
    await send({
      'type': 'req',
      'id': 'memory_sync_${DateTime.now().millisecondsSinceEpoch}',
      'method': 'memory.sync',
      'params': {
        'memories': _memoryService!.entries.map((m) => m.toJson()).toList(),
      },
    });
    
    debugPrint('[OpenClawCollab] 记忆同步请求已发送');
  }
  
  /// 同步任务
  Future<void> syncTasks() async {
    if (!_isConnected) {
      debugPrint('[OpenClawCollab] 无法同步任务');
      return;
    }
    
    await send({
      'type': 'req',
      'id': 'task_sync_${DateTime.now().millisecondsSinceEpoch}',
      'method': 'task.sync',
      'params': {
        'pending': _pendingTasks,
        'completed': _completedTasks,
      },
    });
    
    debugPrint('[OpenClawCollab] 任务同步请求已发送');
  }
  
  /// 请求远程工具调用
  Future<Map<String, dynamic>?> invokeRemoteTool(
    String toolName,
    Map<String, dynamic> params,
  ) async {
    if (!_isConnected) {
      debugPrint('[OpenClawCollab] 无法调用远程工具');
      return null;
    }
    
    final requestId = 'tool_${DateTime.now().millisecondsSinceEpoch}';
    
    await send({
      'type': 'req',
      'id': requestId,
      'method': 'tool.invoke',
      'params': {
        'tool': toolName,
        'arguments': params,
      },
    });
    
    // 等待响应（简化版，实际需要 Completer）
    debugPrint('[OpenClawCollab] 远程工具调用请求已发送: $toolName');
    return null; // TODO: 实现 Completer 等待响应
  }
  
  /// 汇报移动设备状态
  Future<void> reportMobileStatus(Map<String, dynamic> status) async {
    if (!_isConnected) {
      return;
    }
    
    await send({
      'type': 'event',
      'event': 'mobile.status',
      'payload': status,
    });
  }
  
  /// 处理消息
  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      
      debugPrint('[OpenClawCollab] 收到消息: $type');
      
      switch (type) {
        case 'res':
          _handleResponse(message);
          break;
          
        case 'event':
          _handleEvent(message);
          break;
          
        case 'req':
          _handleRequest(message);
          break;
      }
      
      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('[OpenClawCollab] 解析消息失败: $e');
    }
  }
  
  /// 处理响应
  void _handleResponse(Map<String, dynamic> message) {
    final ok = message['ok'] as bool?;
    final payload = message['payload'] as Map<String, dynamic>?;
    
    if (ok == true && payload != null) {
      final type = payload['type'] as String?;
      
      if (type == 'hello-ok') {
        _openclawStatus = OpenClawStatus(
          isOnline: true,
          version: payload['version'] as String?,
          platform: 'unknown',
          lastSync: DateTime.now(),
        );
        debugPrint('[OpenClawCollab] 握手成功');
      }
    }
  }
  
  /// 处理事件
  void _handleEvent(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final payload = message['payload'] as Map<String, dynamic>?;
    
    switch (event) {
      case 'mobile.command':
        _handleMobileCommand(payload);
        break;
        
      case 'memory.updated':
        _handleMemoryUpdate(payload);
        break;
        
      case 'task.assigned':
        _handleTaskAssigned(payload);
        break;
    }
  }
  
  /// 处理请求
  void _handleRequest(Map<String, dynamic> message) {
    final method = message['method'] as String?;
    final params = message['params'] as Map<String, dynamic>?;
    final id = message['id'] as String?;
    
    switch (method) {
      case 'sensor.read':
        _handleSensorRead(id, params);
        break;
        
      case 'location.get':
        _handleLocationGet(id, params);
        break;
    }
  }
  
  /// 处理移动命令
  void _handleMobileCommand(Map<String, dynamic>? payload) {
    if (payload == null) return;
    
    final command = payload['command'] as String?;
    debugPrint('[OpenClawCollab] 收到命令: $command');
  }
  
  /// 处理记忆更新
  void _handleMemoryUpdate(Map<String, dynamic>? payload) {
    if (payload == null || _memoryService == null) return;
    
    // 同步记忆
    debugPrint('[OpenClawCollab] 记忆更新');
  }
  
  /// 处理任务分配
  void _handleTaskAssigned(Map<String, dynamic>? payload) {
    if (payload == null) return;
    
    _pendingTasks.add(payload);
    debugPrint('[OpenClawCollab] 任务已分配: ${payload['id']}');
    notifyListeners();
  }
  
  /// 处理传感器读取
  void _handleSensorRead(String? id, Map<String, dynamic>? params) {
    if (id == null) return;
    
    // TODO: 实际读取传感器数据
    send({
      'type': 'res',
      'id': id,
      'ok': true,
      'payload': {
        'accelerometer': {'x': 0.0, 'y': 0.0, 'z': 9.8},
        'gyroscope': {'x': 0.0, 'y': 0.0, 'z': 0.0},
      },
    });
  }
  
  /// 处理位置获取
  void _handleLocationGet(String? id, Map<String, dynamic>? params) {
    if (id == null) return;
    
    // TODO: 实际获取位置
    send({
      'type': 'res',
      'id': id,
      'ok': true,
      'payload': {
        'latitude': 0.0,
        'longitude': 0.0,
        'accuracy': 0.0,
      },
    });
  }
  
  /// 错误处理
  void _onError(dynamic error) {
    debugPrint('[OpenClawCollab] 错误: $error');
    _isConnected = false;
    notifyListeners();
  }
  
  /// 断开处理
  void _onDisconnect() {
    debugPrint('[OpenClawCollab] 连接断开');
    _isConnected = false;
    _openclawStatus = null;
    notifyListeners();
  }
  
  /// 获取协作统计
  Map<String, dynamic> get statistics {
    return {
      'mode': _mode.name,
      'isConnected': _isConnected,
      'openclawOnline': _openclawStatus?.isOnline ?? false,
      'pendingTasks': _pendingTasks.length,
      'completedTasks': _completedTasks.length,
      'lastSync': _lastSyncTime?.toIso8601String(),
    };
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

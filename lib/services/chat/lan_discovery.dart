// 设备发现服务
//
// 支持 Tailscale 等虚拟网络（使用 TCP 而非 UDP 多播）

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';

/// 发现的设备信息
class DiscoveredDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final bool isBot;
  final DateTime discoveredAt;
  final Map<String, dynamic>? extra;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.port = 18789,
    this.isBot = false,
    required this.discoveredAt,
    this.extra,
  });

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      ipAddress: json['ip'] ?? '',
      port: json['port'] ?? 18789,
      isBot: json['isBot'] ?? false,
      discoveredAt: DateTime.now(),
      extra: json['extra'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ipAddress,
    'port': port,
    'isBot': isBot,
    'extra': extra,
  };
}

/// 发现的房间信息
class DiscoveredRoom {
  final String id;
  final String name;
  final String hostId;
  final String hostName;
  final int memberCount;
  final DateTime discoveredAt;

  DiscoveredRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    this.memberCount = 1,
    required this.discoveredAt,
  });

  factory DiscoveredRoom.fromJson(Map<String, dynamic> json) {
    return DiscoveredRoom(
      id: json['roomId'] ?? '',
      name: json['roomName'] ?? 'Unknown Room',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? 'Unknown',
      memberCount: json['memberCount'] ?? 1,
      discoveredAt: DateTime.now(),
    );
  }
}

/// 设备发现服务（兼容 Tailscale）
class LanDiscoveryService {
  final Logger _logger = Logger();
  
  // TCP 端口配置
  static const int _discoveryPort = 37689;
  static const Duration _connectionTimeout = Duration(seconds: 3);
  static const Duration _deviceTimeout = Duration(seconds: 30);
  
  // 本机信息
  String? _localDeviceId;
  String? _localDeviceName;
  bool _isBot = false;
  String? _currentRoomId;
  String? _currentRoomName;
  
  // 发现的设备
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, DiscoveredRoom> _rooms = {};
  
  // TCP 服务器
  ServerSocket? _server;
  
  // 已知的设备 IP（用于主动探测）
  final List<String> _knownIPs = [];
  
  // 扫描任务
  Timer? _scanTimer;
  bool _isScanning = false;
  
  // 流控制器
  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  final _roomsController = StreamController<List<DiscoveredRoom>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  /// 设备列表流
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  
  /// 房间列表流
  Stream<List<DiscoveredRoom>> get roomsStream => _roomsController.stream;
  
  /// 错误流
  Stream<String> get errorStream => _errorController.stream;
  
  /// 当前发现的设备
  List<DiscoveredDevice> get devices => _devices.values.toList();
  
  /// 当前发现的房间
  List<DiscoveredRoom> get rooms => _rooms.values.toList();
  
  /// 是否正在扫描
  bool get isScanning => _isScanning;
  
  /// 初始化本机信息
  void init({
    required String deviceId,
    required String deviceName,
    bool isBot = false,
  }) {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
    _isBot = isBot;
    _logger.i('设备发现初始化: $deviceName (${isBot ? '机器人' : '用户'})');
  }
  
  /// 设置当前房间（告诉其他设备）
  void setCurrentRoom(String? roomId, String? roomName) {
    _currentRoomId = roomId;
    _currentRoomName = roomName;
  }
  
  /// 启动发现服务
  Future<void> start() async {
    if (_server != null) return;
    
    try {
      _isScanning = true;
      
      // 启动 TCP 服务器（等待其他设备连接）
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
      );
      
      _server!.listen(
        _handleIncomingConnection,
        onError: (error) {
          _logger.e('服务器错误: $error');
          _errorController.add('服务器错误: $error');
        },
      );
      
      _logger.i('发现服务已启动 (端口: $_discoveryPort)');
      
      // 广播当前状态
      _notifyDevices();
      _notifyRooms();
      
    } catch (e) {
      _logger.e('启动发现服务失败: $e');
      _errorController.add('启动发现服务失败: $e');
      _isScanning = false;
    }
  }
  
  /// 停止发现服务
  void stop() {
    _scanTimer?.cancel();
    _server?.close();
    _server = null;
    _isScanning = false;
    _logger.i('发现服务已停止');
  }
  
  /// 扫描指定 IP 地址
  Future<bool> scanIP(String ipAddress) async {
    if (_localDeviceId == null) return false;
    
    _logger.i('扫描 IP: $ipAddress');
    
    try {
      final socket = await Socket.connect(
        ipAddress,
        _discoveryPort,
        timeout: _connectionTimeout,
      );
      
      // 发送发现请求
      final request = jsonEncode({
        'type': 'discover_request',
        'id': _localDeviceId,
        'name': _localDeviceName,
        'isBot': _isBot,
        'roomId': _currentRoomId,
        'roomName': _currentRoomName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      socket.writeln(request);
      
      // 等待响应
      String buffer = '';
      final completer = Completer<bool>();
      
      socket.listen(
        (data) {
          buffer += utf8.decode(data);
          while (buffer.contains('\n')) {
            final index = buffer.indexOf('\n');
            final messageStr = buffer.substring(0, index);
            buffer = buffer.substring(index + 1);
            
            try {
              final data = jsonDecode(messageStr);
              _handleDiscoveryResponse(data, ipAddress);
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } catch (e) {
              _logger.w('解析响应失败: $e');
            }
          }
        },
        onError: (error) {
          _logger.e('连接错误: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
      
      // 超时处理
      Future.delayed(_connectionTimeout, () {
        if (!completer.isCompleted) {
          socket.destroy();
          completer.complete(false);
        }
      });
      
      return await completer.future;
    } catch (e) {
      _logger.w('扫描 $ipAddress 失败: $e');
      return false;
    }
  }
  
  /// 扫描多个 IP 地址
  Future<void> scanIPs(List<String> ipAddresses) async {
    _isScanning = true;
    _notifyDevices();
    
    // 并发扫描所有 IP
    final results = await Future.wait(
      ipAddresses.map((ip) => scanIP(ip)),
    );
    
    _isScanning = false;
    _notifyDevices();
    
    final foundCount = results.where((r) => r).length;
    _logger.i('扫描完成: ${ipAddresses.length} 个地址，发现 $foundCount 个设备');
  }
  
  /// 处理入站连接
  void _handleIncomingConnection(Socket socket) {
    _logger.i('收到连接: ${socket.remoteAddress.address}');
    
    String buffer = '';
    
    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        
        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final messageStr = buffer.substring(0, index);
          buffer = buffer.substring(index + 1);
          
          try {
            final data = jsonDecode(messageStr);
            _handleIncomingMessage(data, socket);
          } catch (e) {
            _logger.w('解析消息失败: $e');
          }
        }
      },
      onError: (error) {
        _logger.e('连接错误: $error');
        socket.destroy();
      },
      onDone: () {
        socket.destroy();
      },
    );
  }
  
  /// 处理入站消息
  void _handleIncomingMessage(Map<String, dynamic> data, Socket socket) {
    final type = data['type'] as String?;
    
    if (type == 'discover_request') {
      // 收到发现请求，回复自己的信息
      _handleDiscoverRequest(data, socket);
    }
  }
  
  /// 处理发现请求
  void _handleDiscoverRequest(Map<String, dynamic> data, Socket socket) {
    final remoteId = data['id'] as String?;
    if (remoteId == null || remoteId == _localDeviceId) return;
    
    // 记录请求方信息
    final device = DiscoveredDevice.fromJson({
      ...data,
      'ip': socket.remoteAddress.address,
    });
    
    _devices[device.id] = device;
    _notifyDevices();
    
    // 如果对方有房间，记录房间
    if (data['roomId'] != null && data['roomName'] != null) {
      final room = DiscoveredRoom.fromJson({
        'roomId': data['roomId'],
        'roomName': data['roomName'],
        'hostId': data['id'],
        'hostName': data['name'],
      });
      
      _rooms[room.id] = room;
      _notifyRooms();
    }
    
    // 回复自己的信息
    final response = jsonEncode({
      'type': 'discover_response',
      'id': _localDeviceId,
      'name': _localDeviceName,
      'isBot': _isBot,
      'roomId': _currentRoomId,
      'roomName': _currentRoomName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    socket.writeln(response);
    
    _logger.i('发现设备: ${device.name}');
  }
  
  /// 处理发现响应
  void _handleDiscoveryResponse(Map<String, dynamic> data, String ipAddress) {
    final remoteId = data['id'] as String?;
    if (remoteId == null || remoteId == _localDeviceId) return;
    
    final device = DiscoveredDevice.fromJson({
      ...data,
      'ip': ipAddress,
    });
    
    _devices[device.id] = device;
    _notifyDevices();
    
    // 如果对方有房间，记录房间
    if (data['roomId'] != null && data['roomName'] != null) {
      final room = DiscoveredRoom.fromJson({
        'roomId': data['roomId'],
        'roomName': data['roomName'],
        'hostId': data['id'],
        'hostName': data['name'],
      });
      
      _rooms[room.id] = room;
      _notifyRooms();
    }
    
    _logger.i('收到设备响应: ${device.name}');
  }
  
  /// 手动添加设备（用于 Tailscale）
  Future<bool> addDeviceManually(String ipAddress) async {
    _logger.i('手动添加设备: $ipAddress');
    
    final found = await scanIP(ipAddress);
    if (!found) {
      _errorController.add('无法连接到 $ipAddress');
    }
    
    return found;
  }
  
  /// 添加已知 IP（用于局域网扫描）
  void addKnownIP(String ip) {
    if (!_knownIPs.contains(ip)) {
      _knownIPs.add(ip);
    }
  }
  
  /// 扫描已知 IP
  Future<void> scanKnownIPs() async {
    if (_knownIPs.isEmpty) {
      _logger.i('没有已知的 IP 地址');
      return;
    }
    
    await scanIPs(_knownIPs);
  }
  
  /// 清理过期设备
  void cleanupExpiredDevices() {
    final now = DateTime.now();
    
    _devices.removeWhere((id, device) {
      final expired = now.difference(device.discoveredAt) > _deviceTimeout;
      return expired;
    });
    
    _rooms.removeWhere((id, room) {
      final expired = now.difference(room.discoveredAt) > _deviceTimeout;
      return expired;
    });
    
    _notifyDevices();
    _notifyRooms();
  }
  
  /// 通知设备列表更新
  void _notifyDevices() {
    if (!_devicesController.isClosed) {
      _devicesController.add(devices);
    }
  }
  
  /// 通知房间列表更新
  void _notifyRooms() {
    if (!_roomsController.isClosed) {
      _roomsController.add(rooms);
    }
  }
  
  /// 清理资源
  void dispose() {
    stop();
    _devicesController.close();
    _roomsController.close();
    _errorController.close();
  }
}

// 局域网设备发现服务
//
// 类似微信面对面入群，自动发现附近的设备和房间

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

/// 局域网发现服务
class LanDiscoveryService {
  final Logger _logger = Logger();
  
  // UDP 多播配置
  static const String _multicastGroup = '239.255.255.250';
  static const int _multicastPort = 37689;
  static const Duration _broadcastInterval = Duration(seconds: 3);
  static const Duration _deviceTimeout = Duration(seconds: 10);
  
  // 本机信息
  String? _localDeviceId;
  String? _localDeviceName;
  bool _isBot = false;
  String? _currentRoomId;
  String? _currentRoomName;
  
  // 发现的设备
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, DiscoveredRoom> _rooms = {};
  
  // UDP Socket
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  
  // 流控制器
  final _devicesController = StreamController<List<DiscoveredDevice>>.broadcast();
  final _roomsController = StreamController<List<DiscoveredRoom>>.broadcast();
  
  /// 设备列表流
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  
  /// 房间列表流
  Stream<List<DiscoveredRoom>> get roomsStream => _roomsController.stream;
  
  /// 当前发现的设备
  List<DiscoveredDevice> get devices => _devices.values.toList();
  
  /// 当前发现的房间
  List<DiscoveredRoom> get rooms => _rooms.values.toList();
  
  /// 初始化本机信息
  void init({
    required String deviceId,
    required String deviceName,
    bool isBot = false,
  }) {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
    _isBot = isBot;
    _logger.i('局域网发现初始化: $deviceName (${isBot ? '机器人' : '用户'})');
  }
  
  /// 设置当前房间（广播给其他设备）
  void setCurrentRoom(String? roomId, String? roomName) {
    _currentRoomId = roomId;
    _currentRoomName = roomName;
  }
  
  /// 开始发现服务
  Future<void> start() async {
    try {
      // 绑定 UDP Socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _multicastPort);
      
      // 加入多播组
      _socket!.joinMulticast(InternetAddress(_multicastGroup));
      
      // 监听消息
      _socket!.listen(_handleMessage);
      
      // 开始广播
      _startBroadcast();
      
      // 开始清理过期设备
      _startCleanup();
      
      _logger.i('局域网发现服务已启动');
    } catch (e) {
      _logger.e('启动局域网发现失败: $e');
    }
  }
  
  /// 停止发现服务
  void stop() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _logger.i('局域网发现服务已停止');
  }
  
  /// 开始广播
  void _startBroadcast() {
    _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
      _broadcast();
    });
    _broadcast(); // 立即广播一次
  }
  
  /// 广播本机信息
  void _broadcast() {
    if (_socket == null || _localDeviceId == null) return;
    
    final message = jsonEncode({
      'type': 'discover',
      'id': _localDeviceId,
      'name': _localDeviceName,
      'isBot': _isBot,
      'roomId': _currentRoomId,
      'roomName': _currentRoomName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    final data = utf8.encode(message);
    _socket!.send(data, InternetAddress(_multicastGroup), _multicastPort);
  }
  
  /// 处理接收到的消息
  void _handleMessage(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    
    final datagram = _socket!.receive();
    if (datagram == null) return;
    
    try {
      final message = utf8.decode(datagram.data);
      final data = jsonDecode(message) as Map<String, dynamic>;
      
      // 忽略自己的消息
      if (data['id'] == _localDeviceId) return;
      
      _handleDiscoverMessage(data, datagram.address.address);
    } catch (e) {
      _logger.w('解析发现消息失败: $e');
    }
  }
  
  /// 处理发现消息
  void _handleDiscoverMessage(Map<String, dynamic> data, String ipAddress) {
    // 添加设备
    final device = DiscoveredDevice.fromJson({
      ...data,
      'ip': ipAddress,
    });
    
    _devices[device.id] = device;
    _notifyDevices();
    
    // 如果有房间信息，添加到房间列表
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
    
    _logger.i('发现设备: ${device.name} ($ipAddress)');
  }
  
  /// 开始清理过期设备
  void _startCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanup();
    });
  }
  
  /// 清理过期设备
  void _cleanup() {
    final now = DateTime.now();
    final timeout = _deviceTimeout;
    
    _devices.removeWhere((id, device) {
      final expired = now.difference(device.discoveredAt) > timeout;
      if (expired) {
        _logger.i('设备过期: ${device.name}');
      }
      return expired;
    });
    
    _rooms.removeWhere((id, room) {
      final expired = now.difference(room.discoveredAt) > timeout;
      return expired;
    });
    
    _notifyDevices();
    _notifyRooms();
  }
  
  /// 通知设备列表更新
  void _notifyDevices() {
    _devicesController.add(devices);
  }
  
  /// 通知房间列表更新
  void _notifyRooms() {
    _roomsController.add(rooms);
  }
  
  /// 清理资源
  void dispose() {
    stop();
    _devicesController.close();
    _roomsController.close();
  }
}

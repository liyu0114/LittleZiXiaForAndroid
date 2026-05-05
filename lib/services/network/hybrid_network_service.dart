// P2P混合网络服务
//
// 支持局域网+Tailscale混合组网

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 网络接口类型
enum NetworkType {
  lan,         // 局域网
  tailscale,  // Tailscale
  relay,       // 中继服务器
}

/// 网络设备
class NetworkDevice {
  final String id;
  final String name;
  final String? lanIP;
  final String? tailscaleIP;
  final bool isOnline;
  final int latencyMs;
  
  NetworkDevice({
    required this.id,
    required this.name,
    this.lanIP,
    this.tailscaleIP,
    this.isOnline = false,
    this.latencyMs = 0,
  });
  
  /// 获取最佳可达IP
  String? get bestIP {
    if (lanIP != null && isOnline) return lanIP;
    if (tailscaleIP != null && isOnline) return tailscaleIP;
    return null;
  }
}

/// 混合网络管理器
class HybridNetworkManager extends ChangeNotifier {
  final List<NetworkDevice> _devices = [];
  final Map<String, NetworkType> _connectionType = {};
  
  List<NetworkDevice> get devices => List.unmodifiable(_devices);
  
  /// 设备发现
  Future<List<NetworkDevice>> discoverDevices() async {
    // TODO: 实现设备发现
    // 1. 局域网发现（UDP广播）
    // 2. Tailscale peers
    // 3. 手动配对
    
    _devices.clear();
    _devices.addAll([
      NetworkDevice(
        id: 'device-1',
        name: '手机A',
        lanIP: '192.168.1.10',
        tailscaleIP: '100.80.1.1',
        isOnline: true,
        latencyMs: 1,
      ),
      NetworkDevice(
        id: 'device-2', 
        name: '电脑B',
        lanIP: '192.168.1.11',
        tailscaleIP: '100.80.1.2',
        isOnline: true,
        latencyMs: 5,
      ),
    ]);
    
    notifyListeners();
    return _devices;
  }
  
  /// 检测网络质量
  Future<int> probeLatency(NetworkDevice device) async {
    // TODO: 探测延迟
    return device.latencyMs;
  }
  
  /// 选择最佳网络路径
  Future<NetworkType> selectBestPath(NetworkDevice device) async {
    // 1. 局域网优先
    if (device.lanIP != null) {
      return NetworkType.lan;
    }
    // 2. Tailscale次之
    if (device.tailscaleIP != null) {
      return NetworkType.tailscale;
    }
    // 3. 中继保底
    return NetworkType.relay;
  }
  
  /// 发送消息到设备（自动选最优路径）
  Future<bool> sendMessage(NetworkDevice device, String message) async {
    final path = await selectBestPath(device);
    _connectionType[device.id] = path;
    
    debugPrint('[HybridNetwork] 发送消息到 ${device.name} via $path');
    // TODO: 实际发送
    return true;
  }
  
  /// 获取连接类型
  NetworkType? getConnectionType(String deviceId) {
    return _connectionType[deviceId];
  }
}
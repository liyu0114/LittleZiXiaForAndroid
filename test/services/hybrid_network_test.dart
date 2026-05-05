// P2P混合网络服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 设备信息
class Device {
  final String id;
  final String name;
  final String ip;
  bool isOnline;
  
  Device({
    required this.id,
    required this.name,
    required this.ip,
    this.isOnline = true,
  });
}

/// 连接类型
enum ConnectionType {
  wifi,
  bluetooth,
  usb,
}

/// 网络节点
class NetworkNode {
  final Device device;
  final ConnectionType type;
  final DateTime connectedAt;
  
  NetworkNode({
    required this.device,
    required this.type,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();
}

/// 混合网络服务
class HybridNetworkService {
  final Map<String, NetworkNode> _nodes = {};
  
  List<NetworkNode> get nodes => _nodes.values.toList();
  
  void addNode(NetworkNode node) {
    _nodes[node.device.id] = node;
  }
  
  void removeNode(String deviceId) {
    _nodes.remove(deviceId);
  }
  
  NetworkNode? getNode(String deviceId) => _nodes[deviceId];
  
  List<NetworkNode> findByType(ConnectionType type) {
    return _nodes.values.where((n) => n.type == type).toList();
  }
  
  List<NetworkNode> getOnlineNodes() {
    return _nodes.values.where((n) => n.device.isOnline).toList();
  }
  
  void setOnline(String deviceId, bool online) {
    final node = _nodes[deviceId];
    if (node != null) {
      node.device.isOnline = online;
    }
  }
  
  int get nodeCount => _nodes.length;
  
  bool isEmpty => _nodes.isEmpty;
  
  void clear() => _nodes.clear();
}

void main() {
  group('L1-06 P2P混合网络测试', () {
    
    test('测试1：添加节点', () {
      final service = HybridNetworkService();
      final device = Device(id: 'd1', name: '设备1', ip: '192.168.1.1');
      service.addNode(NetworkNode(device: device, type: ConnectionType.wifi));
      
      expect(service.nodeCount, 1);
    });
    
    test('测试2：移除节点', () {
      final service = HybridNetworkService();
      final device = Device(id: 'd1', name: '设备1', ip: '192.168.1.1');
      service.addNode(NetworkNode(device: device, type: ConnectionType.wifi));
      service.removeNode('d1');
      
      expect(service.isEmpty, true);
    });
    
    test('测试3：获取节点', () {
      final service = HybridNetworkService();
      final device = Device(id: 'd1', name: '设备1', ip: '192.168.1.1');
      service.addNode(NetworkNode(device: device, type: ConnectionType.wifi));
      
      expect(service.getNode('d1'), isNotNull);
      expect(service.getNode('d1')?.device.name, '设备1');
    });
    
    test('测试4：按类型筛选', () {
      final service = HybridNetworkService();
      final d1 = Device(id: 'd1', name: 'D1', ip: '1');
      final d2 = Device(id: 'd2', name: 'D2', ip: '2');
      service.addNode(NetworkNode(device: d1, type: ConnectionType.wifi));
      service.addNode(NetworkNode(device: d2, type: ConnectionType.bluetooth));
      
      final wifiNodes = service.findByType(ConnectionType.wifi);
      expect(wifiNodes.length, 1);
    });
    
    test('测试5：在线节点', () {
      final service = HybridNetworkService();
      final d1 = Device(id: 'd1', name: 'D1', ip: '1', isOnline: true);
      final d2 = Device(id: 'd2', name: 'D2', ip: '2', isOnline: false);
      service.addNode(NetworkNode(device: d1, type: ConnectionType.wifi));
      service.addNode(NetworkNode(device: d2, type: ConnectionType.wifi));
      
      expect(service.getOnlineNodes().length, 1);
    });
    
    test('测试6：设置在线状态', () {
      final service = HybridNetworkService();
      final device = Device(id: 'd1', name: 'D1', ip: '1', isOnline: false);
      service.addNode(NetworkNode(device: device, type: ConnectionType.wifi));
      
      service.setOnline('d1', true);
      expect(service.getOnlineNodes().length, 1);
    });
    
    test('测试7：多连接类型', () {
      final service = HybridNetworkService();
      final d1 = Device(id: 'd1', name: 'D1', ip: '1');
      final d2 = Device(id: 'd2', name: 'D2', ip: '2');
      final d3 = Device(id: 'd3', name: 'D3', ip: '3');
      service.addNode(NetworkNode(device: d1, type: ConnectionType.wifi));
      service.addNode(NetworkNode(device: d2, type: ConnectionType.bluetooth));
      service.addNode(NetworkNode(device: d3, type: ConnectionType.usb));
      
      expect(service.findByType(ConnectionType.wifi).length, 1);
      expect(service.findByType(ConnectionType.bluetooth).length, 1);
      expect(service.findByType(ConnectionType.usb).length, 1);
    });
    
    test('测试8：清空网络', () {
      final service = HybridNetworkService();
      final d1 = Device(id: 'd1', name: 'D1', ip: '1');
      service.addNode(NetworkNode(device: d1, type: ConnectionType.wifi));
      service.clear();
      
      expect(service.isEmpty, true);
    });
    
    test('测试9：设备IP', () {
      final device = Device(id: 'd1', name: '设备1', ip: '192.168.1.100');
      expect(device.ip, '192.168.1.100');
    });
    
    test('测试10：节点连接时间', () {
      final device = Device(id: 'd1', name: 'D1', ip: '1');
      final node = NetworkNode(device: device, type: ConnectionType.wifi);
      
      expect(node.connectedAt, isNotNull);
    });
  });
}
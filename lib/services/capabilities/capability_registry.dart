// 基础能力注册表
//
// 管理所有"手脚"能力，供 Skill 和任务执行器调用

import 'package:flutter/foundation.dart';

/// 能力类型
enum CapabilityType {
  // 感知能力
  vision,       // 眼：摄像头、二维码
  hearing,      // 耳：麦克风、语音识别
  location,     // 腿：GPS、位置
  sensor,       // 触觉：传感器、加速度计
  
  // 表达能力
  speech,       // 口：TTS、语音播报
  display,      // 显示：屏幕输出
  notification, // 通知：提醒
  
  // 存储能力
  memory,       // 记忆：本地存储
  knowledge,    // 知识：数据库
  
  // 连接能力
  network,      // 网络：HTTP、WebSocket
  bluetooth,    // 蓝牙：设备连接
  nfc,          // NFC：近场通信
  
  // 执行能力
  file,         // 文件：读写操作
  shell,        // 命令：系统命令
  camera,       // 相机：拍照、录像
}

/// 能力状态
enum CapabilityStatus {
  available,    // 可用
  unavailable,  // 不可用
  permissionDenied, // 权限被拒绝
  error,        // 错误
}

/// 能力信息
class Capability {
  final CapabilityType type;
  final String name;
  final String description;
  final IconData? icon;
  CapabilityStatus status;
  String? errorMessage;
  
  Capability({
    required this.type,
    required this.name,
    required this.description,
    this.icon,
    this.status = CapabilityStatus.available,
    this.errorMessage,
  });
}

/// 基础能力注册表
class CapabilityRegistry extends ChangeNotifier {
  static final CapabilityRegistry _instance = CapabilityRegistry._internal();
  factory CapabilityRegistry() => _instance;
  CapabilityRegistry._internal();
  
  // 能力映射
  final Map<CapabilityType, Capability> _capabilities = {};
  
  // 能力执行器
  final Map<CapabilityType, Future<dynamic> Function(Map<String, dynamic> params)> _executors = {};
  
  /// 注册能力
  void register(
    CapabilityType type,
    String name,
    String description, {
    Future<dynamic> Function(Map<String, dynamic> params)? executor,
  }) {
    _capabilities[type] = Capability(
      type: type,
      name: name,
      description: description,
    );
    
    if (executor != null) {
      _executors[type] = executor;
    }
    
    debugPrint('[CapabilityRegistry] 注册能力: $name');
  }
  
  /// 获取能力
  Capability? getCapability(CapabilityType type) {
    return _capabilities[type];
  }
  
  /// 获取所有能力
  List<Capability> getAllCapabilities() {
    return _capabilities.values.toList();
  }
  
  /// 执行能力
  Future<dynamic> execute(CapabilityType type, Map<String, dynamic> params) async {
    final executor = _executors[type];
    if (executor == null) {
      throw Exception('能力 $type 未注册执行器');
    }
    
    try {
      return await executor(params);
    } catch (e) {
      debugPrint('[CapabilityRegistry] 执行能力 $type 失败: $e');
      rethrow;
    }
  }
  
  /// 检查能力是否可用
  bool isAvailable(CapabilityType type) {
    final capability = _capabilities[type];
    return capability?.status == CapabilityStatus.available;
  }
  
  /// 更新能力状态
  void updateStatus(CapabilityType type, CapabilityStatus status, {String? errorMessage}) {
    final capability = _capabilities[type];
    if (capability != null) {
      capability.status = status;
      capability.errorMessage = errorMessage;
      notifyListeners();
    }
  }
  
  /// 初始化所有能力
  Future<void> initialize() async {
    debugPrint('[CapabilityRegistry] 初始化基础能力...');
    
    // 这些将在具体实现中注册
    // 这里只是声明能力存在
  }
}

/// 能力快捷访问
class Capabilities {
  static CapabilityRegistry get registry => CapabilityRegistry();
  
  /// 执行能力
  static Future<T> execute<T>(CapabilityType type, Map<String, dynamic> params) async {
    final result = await registry.execute(type, params);
    return result as T;
  }
  
  /// 检查能力
  static bool isAvailable(CapabilityType type) {
    return registry.isAvailable(type);
  }
}

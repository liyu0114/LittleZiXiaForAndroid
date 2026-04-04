// 能力初始化服务
//
// 在 App 启动时注册所有基础能力

import 'package:flutter/foundation.dart';
import 'capability_registry.dart';
import '../native/location_service.dart';
import '../native/notification_service.dart';
import '../native/shell_service.dart';
import '../voice/tts_service.dart';
import '../sensors/sensor_service.dart';

/// 能力初始化器
class CapabilityInitializer {
  /// 初始化所有基础能力
  static Future<void> initialize() async {
    final registry = CapabilityRegistry();
    
    debugPrint('[CapabilityInitializer] 开始初始化基础能力...');
    
    // ==================== 感知能力 ====================
    
    // 眼：摄像头、二维码
    registry.register(
      CapabilityType.vision,
      '视觉',
      '摄像头拍照、扫描二维码',
      executor: (params) async {
        // TODO: 实现摄像头能力
        throw UnimplementedError('视觉能力待实现');
      },
    );
    
    // 耳：麦克风、语音识别
    registry.register(
      CapabilityType.hearing,
      '听觉',
      '语音识别、录音',
      executor: (params) async {
        // TODO: 实现语音识别能力
        throw UnimplementedError('听觉能力待实现');
      },
    );
    
    // 腿：GPS、位置
    registry.register(
      CapabilityType.location,
      '位置',
      '获取 GPS 位置、逆地理编码',
      executor: (params) async {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        if (position == null) {
          throw Exception('无法获取位置');
        }
        return {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
        };
      },
    );
    
    // 触觉：传感器
    registry.register(
      CapabilityType.sensor,
      '传感器',
      '加速度计、陀螺仪、指南针',
      executor: (params) async {
        // TODO: 实现传感器能力
        throw UnimplementedError('传感器能力待实现');
      },
    );
    
    // ==================== 表达能力 ====================
    
    // 口：TTS、语音播报
    registry.register(
      CapabilityType.speech,
      '语音',
      '文字转语音、语音播报',
      executor: (params) async {
        final text = params['text'] as String?;
        if (text == null) {
          throw Exception('缺少 text 参数');
        }
        
        final tts = TTSService();
        await tts.speak(text);
        return {'success': true};
      },
    );
    
    // 显示：屏幕输出
    registry.register(
      CapabilityType.display,
      '显示',
      '屏幕显示、界面输出',
      executor: (params) async {
        // 显示能力通常由 UI 层直接处理
        return {'success': true};
      },
    );
    
    // 通知：提醒
    registry.register(
      CapabilityType.notification,
      '通知',
      '发送系统通知、设置提醒',
      executor: (params) async {
        final title = params['title'] as String?;
        final body = params['body'] as String?;
        
        if (title == null) {
          throw Exception('缺少 title 参数');
        }
        
        final notificationService = NotificationService();
        await notificationService.showNotification(
          title: title,
          body: body ?? '',
        );
        return {'success': true};
      },
    );
    
    // ==================== 存储能力 ====================
    
    // 记忆：本地存储
    registry.register(
      CapabilityType.memory,
      '记忆',
      '本地数据存储、SharedPreferences',
      executor: (params) async {
        // TODO: 实现存储能力
        throw UnimplementedError('记忆能力待实现');
      },
    );
    
    // 知识：数据库
    registry.register(
      CapabilityType.knowledge,
      '知识',
      '本地数据库、知识库',
      executor: (params) async {
        // TODO: 实现知识库能力
        throw UnimplementedError('知识能力待实现');
      },
    );
    
    // ==================== 连接能力 ====================
    
    // 网络：HTTP
    registry.register(
      CapabilityType.network,
      '网络',
      'HTTP 请求、WebSocket 连接',
      executor: (params) async {
        // TODO: 实现网络能力
        throw UnimplementedError('网络能力待实现');
      },
    );
    
    // 蓝牙
    registry.register(
      CapabilityType.bluetooth,
      '蓝牙',
      '蓝牙扫描、设备连接',
      executor: (params) async {
        // TODO: 实现蓝牙能力
        throw UnimplementedError('蓝牙能力待实现');
      },
    );
    
    // NFC
    registry.register(
      CapabilityType.nfc,
      'NFC',
      'NFC 读取、写入',
      executor: (params) async {
        // TODO: 实现 NFC 能力
        throw UnimplementedError('NFC 能力待实现');
      },
    );
    
    // ==================== 执行能力 ====================
    
    // 文件：读写
    registry.register(
      CapabilityType.file,
      '文件',
      '文件读写、文件选择',
      executor: (params) async {
        // TODO: 实现文件能力
        throw UnimplementedError('文件能力待实现');
      },
    );
    
    // 命令：Shell
    registry.register(
      CapabilityType.shell,
      '命令',
      '执行系统命令',
      executor: (params) async {
        final command = params['command'] as String?;
        if (command == null) {
          throw Exception('缺少 command 参数');
        }
        
        final shellService = ShellService();
        final result = await shellService.execute(command);
        return {'output': result};
      },
    );
    
    // 相机：拍照
    registry.register(
      CapabilityType.camera,
      '相机',
      '拍照、录像',
      executor: (params) async {
        // TODO: 实现相机能力
        throw UnimplementedError('相机能力待实现');
      },
    );
    
    debugPrint('[CapabilityInitializer] 基础能力初始化完成，共 ${registry.getAllCapabilities().length} 个能力');
  }
  
  /// 获取能力状态摘要
  static Map<String, dynamic> getStatusSummary() {
    final registry = CapabilityRegistry();
    final capabilities = registry.getAllCapabilities();
    
    final available = capabilities.where((c) => c.status == CapabilityStatus.available).length;
    final unavailable = capabilities.where((c) => c.status == CapabilityStatus.unavailable).length;
    
    return {
      'total': capabilities.length,
      'available': available,
      'unavailable': unavailable,
    };
  }
}

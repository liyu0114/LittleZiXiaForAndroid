// L2 原生能力服务
//
// 提供相机、位置、通知等原生功能

import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// 原生能力服务
class NativeCapabilities {
  /// 请求相机权限
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 请求位置权限
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 检查所有权限状态
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': await Permission.camera.isGranted,
      'location': await Permission.location.isGranted,
      'notification': await Permission.notification.isGranted,
      'storage': await Permission.storage.isGranted,
    };
  }

  /// 打开应用设置
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
}

/// 位置信息
class LocationInfo {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 相机服务（需要平台实现）
class CameraService {
  static Future<File?> takePhoto() async {
    // TODO: 实现 camera 插件调用
    throw UnimplementedError('Camera service not implemented');
  }

  static Future<File?> pickFromGallery() async {
    // TODO: 实现 image_picker 插件调用
    throw UnimplementedError('Gallery service not implemented');
  }
}

/// 位置服务（需要平台实现）
class LocationService {
  static Future<LocationInfo?> getCurrentLocation() async {
    // TODO: 实现 geolocator 插件调用
    throw UnimplementedError('Location service not implemented');
  }
}

/// 通知服务
class NotificationService {
  static Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    // TODO: 实现 flutter_local_notifications 插件调用
    throw UnimplementedError('Notification service not implemented');
  }
}

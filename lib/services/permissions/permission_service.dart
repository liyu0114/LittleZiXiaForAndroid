// 权限请求服务
//
// 在 APP 启动时主动请求所有必要权限

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // 必需权限列表
  static const List<Permission> _requiredPermissions = [
    Permission.location,
    Permission.camera,
    Permission.microphone,
    Permission.storage,
    Permission.notification,
    Permission.activityRecognition,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ];

  // 可选权限列表
  static const List<Permission> _optionalPermissions = [
    Permission.locationAlways,
    Permission.sensors,
  ];

  /// 请求所有必需权限
  Future<Map<Permission, PermissionStatus>> requestRequiredPermissions() async {
    final Map<Permission, PermissionStatus> results = {};

    for (final permission in _requiredPermissions) {
      final status = await permission.request();
      results[permission] = status;
      debugPrint('[Permission] ${permission.toString()}: $status');
    }

    return results;
  }

  /// 请求单个权限
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    debugPrint('[Permission] ${permission.toString()}: $status');
    return status.isGranted;
  }

  /// 检查权限状态
  Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }

  /// 检查所有必需权限是否已授予
  Future<bool> hasAllRequiredPermissions() async {
    for (final permission in _requiredPermissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  /// 获取未授予的权限列表
  Future<List<Permission>> getDeniedPermissions() async {
    final List<Permission> denied = [];

    for (final permission in _requiredPermissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        denied.add(permission);
      }
    }

    return denied;
  }

  /// 打开应用设置页面
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// 权限名称映射（用于显示）
  static String getPermissionName(Permission permission) {
    final nameMap = {
      Permission.location: '位置',
      Permission.locationAlways: '后台位置',
      Permission.locationWhenInUse: '使用时位置',
      Permission.camera: '相机',
      Permission.microphone: '麦克风',
      Permission.storage: '存储',
      Permission.notification: '通知',
      Permission.activityRecognition: '活动识别',
      Permission.bluetoothScan: '蓝牙扫描',
      Permission.bluetoothConnect: '蓝牙连接',
      Permission.sensors: '传感器',
      Permission.contacts: '联系人',
      Permission.phone: '电话',
      Permission.sms: '短信',
    };

    return nameMap[permission] ?? permission.toString();
  }

  /// 权限描述映射（用于说明）
  static String getPermissionDescription(Permission permission) {
    final descMap = {
      Permission.location: '用于获取您的当前位置，提供本地天气、附近搜索等服务',
      Permission.locationAlways: '允许在后台获取位置，提供持续的位置服务',
      Permission.locationWhenInUse: '仅在使用时获取位置',
      Permission.camera: '用于扫描二维码、拍照等功能',
      Permission.microphone: '用于语音输入和语音唤醒',
      Permission.storage: '用于保存文件和读取本地数据',
      Permission.notification: '用于发送提醒和通知',
      Permission.activityRecognition: '用于计步器和运动检测',
      Permission.bluetoothScan: '用于扫描附近的蓝牙设备',
      Permission.bluetoothConnect: '用于连接蓝牙设备',
      Permission.sensors: '用于访问传感器数据（指南针、海拔等）',
    };

    return descMap[permission] ?? '需要此权限以提供完整功能';
  }
}

/// 权限请求对话框
class PermissionRequestDialog extends StatelessWidget {
  final List<Permission> permissions;
  final VoidCallback onGranted;
  final VoidCallback onDenied;

  const PermissionRequestDialog({
    super.key,
    required this.permissions,
    required this.onGranted,
    required this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('需要权限'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('小紫霞需要以下权限以提供完整功能：'),
          const SizedBox(height: 16),
          ...permissions.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PermissionService.getPermissionName(p),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        PermissionService.getPermissionDescription(p),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDenied,
          child: const Text('暂不授权'),
        ),
        ElevatedButton(
          onPressed: onGranted,
          child: const Text('授予权限'),
        ),
      ],
    );
  }
}

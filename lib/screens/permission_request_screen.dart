// 首次启动权限请求页面
//
// 引导用户授予必要权限

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_state.dart';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const PermissionRequestScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  Map<Permission, PermissionStatus>? _permissionResults;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final hasAll = await appState.hasAllPermissions();

    if (hasAll) {
      // 已有所有权限，直接进入
      widget.onCompleted();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isRequesting = true;
    });

    final appState = Provider.of<AppState>(context, listen: false);
    final results = await appState.requestPermissions();

    setState(() {
      _permissionResults = results;
      _isRequesting = false;
    });

    // 检查关键权限
    final critical = [
      Permission.location,
      Permission.camera,
      Permission.microphone,
    ];

    final allCriticalGranted = critical.every((p) => results[p]?.isGranted ?? false);

    if (allCriticalGranted) {
      // 关键权限已授予，继续
      await Future.delayed(const Duration(seconds: 1));
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo 和标题
              const Icon(
                Icons.security,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                '需要您的授权',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '小紫霞需要以下权限以提供完整功能',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // 权限列表
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      icon: Icons.location_on,
                      title: '位置信息',
                      description: '获取您的位置，提供本地天气、附近搜索等服务',
                      permission: Permission.location,
                    ),
                    _buildPermissionItem(
                      icon: Icons.camera_alt,
                      title: '相机',
                      description: '扫描二维码、拍照等功能',
                      permission: Permission.camera,
                    ),
                    _buildPermissionItem(
                      icon: Icons.mic,
                      title: '麦克风',
                      description: '语音输入和语音唤醒',
                      permission: Permission.microphone,
                    ),
                    _buildPermissionItem(
                      icon: Icons.folder,
                      title: '存储',
                      description: '保存文件和读取本地数据',
                      permission: Permission.storage,
                    ),
                    _buildPermissionItem(
                      icon: Icons.notifications,
                      title: '通知',
                      description: '发送提醒和通知',
                      permission: Permission.notification,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 按钮
              if (_isRequesting)
                const CircularProgressIndicator()
              else if (_permissionResults == null)
                ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('授予权限'),
                )
              else
                Column(
                  children: [
                    Text(
                      '部分权限被拒绝，某些功能可能受限',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onCompleted,
                            child: const Text('稍后再说'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final appState = Provider.of<AppState>(context, listen: false);
                              await appState.openPermissionSettings();
                            },
                            child: const Text('打开设置'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Permission permission,
  }) {
    final status = _permissionResults?[permission];
    final isGranted = status?.isGranted ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? Colors.green : Colors.grey,
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: _permissionResults == null
            ? null
            : Icon(
                isGranted ? Icons.check_circle : Icons.cancel,
                color: isGranted ? Colors.green : Colors.red,
              ),
      ),
    );
  }
}

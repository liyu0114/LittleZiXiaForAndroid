// 协作界面
//
// 整合 P2P 组网 + Gateway 连接

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/app_state.dart';
import '../services/collaboration/multi_device_service.dart';
import '../services/remote/remote_connection.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _gatewayUrlController = TextEditingController();
  final _gatewayTokenController = TextEditingController();
  final _manualAddressController = TextEditingController();

  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gatewayUrlController.dispose();
    _gatewayTokenController.dispose();
    _manualAddressController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final appState = context.read<AppState>();
    final connection = appState.remoteConnection;
    if (connection != null) {
      _gatewayUrlController.text = connection.url;
      if (connection.token != null) {
        _gatewayTokenController.text = connection.token!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('协作'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '服务器'),
            Tab(text: '客户端'),
            Tab(text: 'Gateway'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServerTab(),
          _buildClientTab(),
          _buildGatewayTab(),
        ],
      ),
    );
  }

  // ==================== Server Tab ====================

  Widget _buildServerTab() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final collabService = appState.collabService;
        final localDevice = collabService?.localDevice;
        final connectedDevices = collabService?.connectedDevices ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 本机信息
              _buildLocalDeviceCard(localDevice),
              const SizedBox(height: 24),

              // 广播控制
              _buildAdvertisingControl(collabService),
              const SizedBox(height: 24),

              // 二维码（广播时显示）
              if (collabService?.isAdvertising == true) ...[
                _buildQRCodeSection(localDevice),
                const SizedBox(height: 24),
              ],

              // 已连接设备
              if (connectedDevices.isNotEmpty) ...[
                _buildConnectedDevicesList(connectedDevices),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalDeviceCard(DeviceInfo? device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.name ?? '小紫霞设备',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        device?.id ?? '未初始化',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRoleChip(device?.role ?? 'worker'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final (icon, label, color) = switch (role) {
      'leader' => (Icons.star, '领导者', Colors.amber),
      'worker' => (Icons.work, '工作者', Colors.blue),
      'observer' => (Icons.visibility, '观察者', Colors.grey),
      _ => (Icons.help, '未知', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildAdvertisingControl(MultiDeviceCollaborationService? service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '广播控制',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: service?.isAdvertising == true
                    ? null
                    : () async {
                        await service?.startAdvertising();
                      },
                icon: const Icon(Icons.campaign),
                label: const Text('开始广播'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: service?.isAdvertising != true
                    ? null
                    : () async {
                        await service?.stopAdvertising();
                      },
                icon: const Icon(Icons.stop),
                label: const Text('停止广播'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: service?.role ?? 'worker',
                decoration: const InputDecoration(
                  labelText: '角色',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'leader', child: Text('领导者')),
                  DropdownMenuItem(value: 'worker', child: Text('工作者')),
                  DropdownMenuItem(value: 'observer', child: Text('观察者')),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await service?.setRole(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRCodeSection(DeviceInfo? device) {
    // 生成连接信息
    final connectionInfo = {
      'type': 'little_zixia_p2p',
      'name': device?.name ?? '小紫霞设备',
      'id': device?.id ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final qrData = connectionInfo.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '二维码',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '其他设备扫描此二维码连接',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedDevicesList(List<DeviceInfo> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '已连接设备',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${devices.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...devices.map((device) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(device.name[0]),
            ),
            title: Text(device.name),
            subtitle: Text(
              '${device.platform} · ${device.role}',
              style: TextStyle(fontSize: 11),
            ),
            trailing: _buildRoleChip(device.role),
          ),
        )),
      ],
    );
  }

  // ==================== Client Tab ====================

  Widget _buildClientTab() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final collabService = appState.collabService;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设备发现
              _buildDiscoverySection(collabService),
              const SizedBox(height: 24),

              // 扫描二维码
              _buildScanQRSection(),
              const SizedBox(height: 24),

              // 手动输入
              _buildManualInputSection(collabService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoverySection(MultiDeviceCollaborationService? service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设备发现',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: service?.isScanning == true
                    ? null
                    : () async {
                        await service?.startDiscovery();
                      },
                icon: const Icon(Icons.search),
                label: const Text('开始搜索'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: service?.isScanning != true
                    ? null
                    : () async {
                        await service?.stopDiscovery();
                      },
                icon: const Icon(Icons.stop),
                label: const Text('停止搜索'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanQRSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '扫描二维码',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_isScanning) ...[
          SizedBox(
            height: 300,
            child: MobileScanner(
              controller: _scannerController ??= MobileScannerController(),
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final value = barcodes.first.rawValue;
                  if (value != null) {
                    // 解析二维码并连接
                    _handleQRCode(value);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isScanning = false;
                  _scannerController?.dispose();
                  _scannerController = null;
                });
              },
              child: const Text('取消扫描'),
            ),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _isScanning = true;
                _scannerController = MobileScannerController();
              });
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('开始扫描'),
          ),
        ],
      ],
    );
  }

  Widget _buildManualInputSection(MultiDeviceCollaborationService? service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手动连接',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _manualAddressController,
          decoration: const InputDecoration(
            labelText: '设备地址',
            hintText: '设备 ID 或 IP:Port',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final address = _manualAddressController.text.trim();
            if (address.isNotEmpty) {
              await service?.connectToDevice(address);
            }
          },
          icon: const Icon(Icons.link),
          label: const Text('连接'),
        ),
      ],
    );
  }

  // ==================== Gateway Tab ====================

  Widget _buildGatewayTab() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final connection = appState.remoteConnection;
        final state = connection?.state ?? RemoteConnectionState.disconnected;
        final gatewayInfo = connection?.gatewayInfo;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 连接状态
              _buildConnectionStatusCard(state, gatewayInfo),
              const SizedBox(height: 24),

              // Gateway 配置
              _buildGatewayConfigSection(connection),
              const SizedBox(height: 24),

              // Gateway 信息
              if (gatewayInfo != null) ...[
                _buildGatewayInfoCard(gatewayInfo),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatusCard(
    RemoteConnectionState state,
    GatewayInfo? info,
  ) {
    final (icon, label, color) = switch (state) {
      RemoteConnectionState.connected => (Icons.check_circle, '已连接', Colors.green),
      RemoteConnectionState.connecting => (Icons.sync, '连接中...', Colors.orange),
      RemoteConnectionState.error => (Icons.error, '连接错误', Colors.red),
      RemoteConnectionState.disconnected => (Icons.cancel, '未连接', Colors.grey),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label),
        subtitle: Text(
          info?.platform ?? '无 Gateway 信息',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildGatewayConfigSection(RemoteConnection? connection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gateway 配置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gatewayUrlController,
          decoration: const InputDecoration(
            labelText: 'Gateway URL',
            hintText: 'ws://100.80.206.8:18789',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gatewayTokenController,
          decoration: const InputDecoration(
            labelText: 'Token（可选）',
            hintText: '留空表示无需认证',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: connection?.state == RemoteConnectionState.connected
                    ? null
                    : _connectToGateway,
                icon: const Icon(Icons.link),
                label: const Text('连接'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: connection?.state != RemoteConnectionState.connected
                    ? null
                    : () async {
                        await connection?.disconnect();
                      },
                icon: const Icon(Icons.link_off),
                label: const Text('断开'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGatewayInfoCard(GatewayInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gateway 信息',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('版本', info.version),
                _buildInfoRow('平台', info.platform),
                _buildInfoRow('协议版本', info.protocolVersion.toString()),
                if (info.features.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '特性:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: info.features.keys.map((feature) {
                      return Chip(
                        label: Text(feature, style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Helper Methods ====================

  Future<void> _connectToGateway() async {
    if (_gatewayUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Gateway URL')),
      );
      return;
    }

    try {
      final appState = context.read<AppState>();
      final connection = RemoteConnection(
        url: _gatewayUrlController.text.trim(),
        token: _gatewayTokenController.text.trim().isEmpty
            ? null
            : _gatewayTokenController.text.trim(),
      );

      final success = await connection.connect();

      if (success && mounted) {
        appState.setRemoteConnection(connection);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: ${connection.error ?? "未知错误"}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接出错: $e')),
        );
      }
    }
  }

  void _handleQRCode(String value) {
    // 解析二维码并连接
    try {
      // TODO: 解析 JSON 并连接
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描到: $value')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e')),
      );
    }
  }
}

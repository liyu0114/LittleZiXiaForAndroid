// P2P 连接界面
//
// 显示节点信息和连接管理

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/p2p_node_manager.dart';

class P2PConnectionScreen extends StatefulWidget {
  const P2PConnectionScreen({super.key});

  @override
  State<P2PConnectionScreen> createState() => _P2PConnectionScreenState();
}

class _P2PConnectionScreenState extends State<P2PConnectionScreen> {
  final _addressController = TextEditingController();
  bool _isScanning = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _startServer() async {
    final manager = context.read<P2PNodeManager>();
    final success = await manager.startServer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '服务器已启动' : '启动失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _connectToServer() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }

    final manager = context.read<P2PNodeManager>();
    final success = await manager.connectToServer(address);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已连接' : '连接失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final value = barcodes.first.rawValue;
    if (value != null) {
      _addressController.text = value;
      setState(() => _isScanning = false);
      _connectToServer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P 连接'),
      ),
      body: Consumer<P2PNodeManager>(
        builder: (context, manager, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 本地节点信息
                _buildLocalNodeCard(manager),
                const SizedBox(height: 24),

                // 角色选择
                _buildRoleSection(manager),
                const SizedBox(height: 24),

                // 二维码（服务器模式）
                if (manager.isServer) ...[
                  _buildQRCodeSection(manager),
                  const SizedBox(height: 24),
                ],

                // 连接输入（客户端模式）
                if (manager.localNode.role == NodeRole.client) ...[
                  _buildConnectSection(manager),
                  const SizedBox(height: 24),
                ],

                // 远程节点列表
                if (manager.remoteNodes.isNotEmpty) ...[
                  _buildRemoteNodesSection(manager),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocalNodeCard(P2PNodeManager manager) {
    final node = manager.localNode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  node.statusIcon,
                  style: TextStyle(
                    fontSize: 24,
                    color: node.status == NodeStatus.online || 
                           node.status == NodeStatus.connected
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        node.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRoleChip(node.role),
              ],
            ),
            if (node.address != null) ...[
              const SizedBox(height: 8),
              Text(
                '地址: ${node.address}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(NodeRole role) {
    final (icon, label, color) = switch (role) {
      NodeRole.server => (Icons.dns, '服务器', Colors.blue),
      NodeRole.client => (Icons.devices, '客户端', Colors.green),
      NodeRole.standalone => (Icons.phone_android, '独立', Colors.grey),
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

  Widget _buildRoleSection(P2PNodeManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择角色',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRoleCard(
                icon: Icons.dns,
                title: '服务器',
                subtitle: '其他设备连接到你',
                selected: manager.isServer,
                onTap: () async {
                  if (!manager.isServer) {
                    await _startServer();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleCard(
                icon: Icons.devices,
                title: '客户端',
                subtitle: '连接到服务器',
                selected: manager.localNode.role == NodeRole.client,
                onTap: () {
                  manager.disconnect();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(P2PNodeManager manager) {
    final address = manager.localNode.address ?? '';

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
              data: address,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SelectableText(
            address,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectSection(P2PNodeManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '连接到服务器',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: '服务器地址',
            hintText: '192.168.1.100:18790',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                setState(() => _isScanning = true);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isScanning ? null : () {
                  setState(() => _isScanning = true);
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫码'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: manager.localNode.status == NodeStatus.connecting
                    ? null
                    : _connectToServer,
                icon: const Icon(Icons.link),
                label: const Text('连接'),
              ),
            ),
          ],
        ),

        // 扫描器
        if (_isScanning) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: _onDetect,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _isScanning = false);
              },
              child: const Text('取消扫描'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteNodesSection(P2PNodeManager manager) {
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
                '${manager.remoteNodes.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...manager.remoteNodes.map((node) => _buildRemoteNodeTile(node)),
      ],
    );
  }

  Widget _buildRemoteNodeTile(NodeInfo node) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(node.displayName[0]),
        ),
        title: Text(node.displayName),
        subtitle: Text(
          node.address ?? '',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        trailing: Text(
          node.statusIcon,
          style: TextStyle(
            fontSize: 20,
            color: node.status == NodeStatus.connected ? Colors.green : Colors.grey,
          ),
        ),
      ),
    );
  }
}

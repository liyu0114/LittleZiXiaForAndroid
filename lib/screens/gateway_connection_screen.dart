// Gateway 连接界面
//
// 管理 Gateway 连接配置和状态

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gateway_config.dart';
import '../services/gateway_connection_manager.dart';

class GatewayConnectionScreen extends StatefulWidget {
  const GatewayConnectionScreen({super.key});

  @override
  State<GatewayConnectionScreen> createState() => _GatewayConnectionScreenState();
}

class _GatewayConnectionScreenState extends State<GatewayConnectionScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '18789');
  final _tokenController = TextEditingController();

  GatewayConfig? _selectedPreset;
  ConnectionType _connectionType = ConnectionType.tailscale;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    // 默认选中飞书龙虾
    _selectPreset(PresetGateways.feishuLobster);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _selectPreset(GatewayConfig config) {
    setState(() {
      _selectedPreset = config;
      _connectionType = config.type;
      _hostController.text = config.host;
      _portController.text = config.port.toString();
      _tokenController.text = config.token;
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedPreset = null;
      _connectionType = ConnectionType.custom;
    });
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;

    setState(() => _isTesting = true);

    try {
      final config = _buildConfig();
      final manager = context.read<GatewayConnectionManager>();
      
      // 先断开现有连接
      manager.disconnect();
      
      // 尝试连接
      final success = await manager.connect(config);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '连接成功' : '连接失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  GatewayConfig _buildConfig() {
    if (_selectedPreset != null) {
      return _selectedPreset!;
    }

    return GatewayConfig(
      name: '自定义',
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 18789,
      token: _tokenController.text,
      type: ConnectionType.custom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateway 连接'),
      ),
      body: Consumer<GatewayConnectionManager>(
        builder: (context, manager, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 连接状态
                _buildStatusCard(manager),
                const SizedBox(height: 24),

                // 预设选择
                _buildPresetSection(),
                const SizedBox(height: 24),

                // 自定义配置
                if (_connectionType == ConnectionType.custom)
                  _buildCustomSection(),

                // 操作按钮
                const SizedBox(height: 24),
                _buildActionButtons(manager),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(GatewayConnectionManager manager) {
    final info = manager.connectionInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  info.statusIcon,
                  style: TextStyle(
                    fontSize: 24,
                    color: info.isConnected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  info.statusText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (info.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                info.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            if (info.isConnected) ...[
              const SizedBox(height: 8),
              Text(
                '延迟: ${info.latencyText}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快速选择',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...PresetGateways.defaults.map((config) => _buildPresetTile(config)),
        _buildCustomTile(),
      ],
    );
  }

  Widget _buildPresetTile(GatewayConfig config) {
    final isSelected = _selectedPreset?.name == config.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: RadioListTile<GatewayConfig>(
        value: config,
        groupValue: _selectedPreset,
        onChanged: (value) {
          if (value != null) _selectPreset(value);
        },
        title: Text(config.name),
        subtitle: Text(
          '${config.host}:${config.port}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        secondary: _buildTypeChip(config.type),
      ),
    );
  }

  Widget _buildCustomTile() {
    final isSelected = _connectionType == ConnectionType.custom;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: RadioListTile<ConnectionType>(
        value: ConnectionType.custom,
        groupValue: _connectionType,
        onChanged: (value) {
          if (value != null) _selectCustom();
        },
        title: const Text('自定义'),
        subtitle: Text(
          '手动输入地址和 Token',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        secondary: _buildTypeChip(ConnectionType.custom),
      ),
    );
  }

  Widget _buildTypeChip(ConnectionType type) {
    final (icon, label) = switch (type) {
      ConnectionType.tailscale => (Icons.vpn_lock, 'Tailscale'),
      ConnectionType.local => (Icons.computer, '本地'),
      ConnectionType.custom => (Icons.edit, '自定义'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCustomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自定义配置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: '主机地址',
            hintText: '100.80.206.8',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: '端口',
            hintText: '18789',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tokenController,
          decoration: const InputDecoration(
            labelText: 'Token',
            hintText: 'Gateway Token',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildActionButtons(GatewayConnectionManager manager) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_isTesting ? '测试中...' : '测试连接'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: manager.isConnected
                ? () => manager.disconnect()
                : _testConnection,
            icon: Icon(
              manager.isConnected ? Icons.link_off : Icons.link,
            ),
            label: Text(manager.isConnected ? '断开' : '连接'),
          ),
        ),
      ],
    );
  }
}

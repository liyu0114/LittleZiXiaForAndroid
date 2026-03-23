import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/capabilities/capability_manager.dart';

class CapabilityScreen extends StatelessWidget {
  const CapabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final config = appState.capabilityConfig;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // L1 基础模式
            _buildLevelCard(
              context,
              level: CapabilityLevel.l1Basic,
              isEnabled: config.l1Enabled,
              onChanged: (value) {
                // L1 始终开启，不可关闭
              },
            ),

            const SizedBox(height: 16),

            // L2 增强模式
            _buildLevelCard(
              context,
              level: CapabilityLevel.l2Native,
              isEnabled: config.l2Enabled,
              onChanged: (value) {
                _updateConfig(context, config.copyWith(l2Enabled: value));
              },
            ),

            const SizedBox(height: 16),

            // L3 系统模式
            _buildLevelCard(
              context,
              level: CapabilityLevel.l3System,
              isEnabled: config.l3Enabled,
              onChanged: (value) {
                if (value && !config.l3AdbAuthorized) {
                  _showAdbAuthDialog(context, config);
                } else {
                  _updateConfig(context, config.copyWith(l3Enabled: value));
                }
              },
            ),

            const SizedBox(height: 16),

            // L4 远程模式
            _buildLevelCard(
              context,
              level: CapabilityLevel.l4Remote,
              isEnabled: config.l4Enabled,
              onChanged: (value) {
                if (value && config.l4RemoteUrl == null) {
                  _showRemoteConfigDialog(context, config);
                } else {
                  _updateConfig(context, config.copyWith(l4Enabled: value));
                }
              },
            ),

            const SizedBox(height: 24),

            // 当前状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前启用的能力',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (config.l1Enabled)
                          _buildChip('L1 基础', Colors.green),
                        if (config.l2Enabled)
                          _buildChip('L2 增强', Colors.blue),
                        if (config.l3Enabled && config.l3AdbAuthorized)
                          _buildChip('L3 系统', Colors.orange),
                        if (config.l4Enabled && config.l4RemoteUrl != null)
                          _buildChip('L4 远程', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required CapabilityLevel level,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    final info = capabilityLevelInfos[level]!;
    final hasRisk = info['riskWarning'].toString().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(info['icon'] as String)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        info['description'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: level == CapabilityLevel.l1Basic ? null : onChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...((info['features'] as List).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    f as String,
                    style: const TextStyle(fontSize: 13),
                  ),
                ))),
            if (hasRisk) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info['riskWarning'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'chat':
        return Icons.chat;
      case 'devices':
        return Icons.devices;
      case 'terminal':
        return Icons.terminal;
      case 'cloud':
        return Icons.cloud;
      default:
        return Icons.extension;
    }
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  void _updateConfig(BuildContext context, CapabilityConfig newConfig) {
    context.read<AppState>().updateCapabilityConfig(newConfig);
  }

  void _showAdbAuthDialog(BuildContext context, CapabilityConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('ADB 授权确认'),
          ],
        ),
        content: const Text(
          '系统模式需要 ADB 调试权限。\n\n'
          '开启后，紫霞可以执行系统级命令，包括：\n'
          '• Shell 命令\n'
          '• 应用管理\n'
          '• 系统设置\n\n'
          '请确保您了解风险后再继续。\n\n'
          '是否确认授权？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateConfig(
                context,
                config.copyWith(
                  l3Enabled: true,
                  l3AdbAuthorized: true,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('L3 系统模式已启用'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确认授权'),
          ),
        ],
      ),
    );
  }

  void _showRemoteConfigDialog(BuildContext context, CapabilityConfig config) {
    final urlController = TextEditingController(text: config.l4RemoteUrl ?? '');
    final tokenController = TextEditingController(text: config.l4RemoteToken ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('远程连接配置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入远程龙虾的地址和 Token：\n',
              style: TextStyle(color: Colors.grey),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Gateway URL',
                hintText: 'http://192.168.1.100:18789',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入 Gateway URL'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _updateConfig(
                context,
                config.copyWith(
                  l4Enabled: true,
                  l4RemoteUrl: url,
                  l4RemoteToken: tokenController.text.trim(),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('L4 远程模式已启用'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

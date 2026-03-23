import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/remote/remote_connection.dart';

/// Gateway 控制面板
/// 
/// 显示 Gateway 状态、会话列表、任务列表
class GatewayDashboard extends StatefulWidget {
  const GatewayDashboard({super.key});

  @override
  State<GatewayDashboard> createState() => _GatewayDashboardState();
}

class _GatewayDashboardState extends State<GatewayDashboard> {
  @override
  void initState() {
    super.initState();
    // 自动连接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.capabilityConfig.l4Enabled && !appState.isRemoteConnected) {
        appState.connectRemote();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionStatus(appState),
              const SizedBox(height: 16),
              _buildGatewayInfo(appState),
              const SizedBox(height: 16),
              _buildSessionList(appState),
              const SizedBox(height: 16),
              _buildTaskList(appState),
              const SizedBox(height: 16),
              _buildQuickActions(appState),
            ],
          ),
        );
      },
    );
  }

  /// 连接状态卡片
  Widget _buildConnectionStatus(AppState appState) {
    final isConnected = appState.isRemoteConnected;
    final config = appState.capabilityConfig;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? '已连接到 Gateway' : '未连接',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (config.l4RemoteUrl != null)
                        Text(
                          config.l4RemoteUrl!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isConnected)
                  ElevatedButton.icon(
                    onPressed: () => appState.connectRemote(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('连接'),
                  ),
              ],
            ),
            if (appState.remoteConnection?.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.remoteConnection!.error!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
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

  /// Gateway 信息
  Widget _buildGatewayInfo(AppState appState) {
    if (!appState.isRemoteConnected) {
      return const SizedBox.shrink();
    }

    final info = appState.gatewayInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gateway 信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('状态', '运行中', Colors.green),
            if (info != null) ...[
              _buildInfoRow('版本', info.version, null),
              _buildInfoRow('协议版本', info.protocolVersion.toString(), null),
              _buildInfoRow('平台', info.platform, null),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 会话列表
  Widget _buildSessionList(AppState appState) {
    final sessions = appState.sessions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '会话列表 (${sessions.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _createNewSession(appState),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('没有会话')),
              )
            else
              ...sessions.map((session) => _buildSessionItem(session, appState)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(SessionInfo session, AppState appState) {
    final isActive = session.status == 'active';
    
    return ListTile(
      dense: true,
      leading: Icon(
        isActive ? Icons.circle : Icons.radio_button_unchecked,
        color: isActive ? Colors.green : Colors.grey,
        size: 16,
      ),
      title: Text(session.name),
      subtitle: Text(
        session.id,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'switch', child: Text('切换')),
          const PopupMenuItem(value: 'restart', child: Text('重启')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        onSelected: (value) async {
          if (value == 'restart') {
            final success = await appState.restartSession(session.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(success ? '会话已重启' : '重启失败')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$value: ${session.name}')),
            );
          }
        },
      ),
    );
  }

  /// 任务列表
  Widget _buildTaskList(AppState appState) {
    final tasks = appState.remoteTasks;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '远程任务 (${tasks.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (tasks.isNotEmpty)
                  TextButton(
                    onPressed: () => _cancelAllTasks(appState),
                    child: const Text('全部取消'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, 
                           size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        '没有运行中的任务',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...tasks.map((task) => _buildTaskItem(task, appState)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, AppState appState) {
    final taskId = task['id'] ?? task['taskId'] ?? '';
    final description = task['description'] ?? task['name'] ?? 'Unknown task';
    final progress = task['progress'] as double? ?? 0.0;
    final status = task['status'] ?? 'running';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'running' ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status == 'running')
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Expanded(child: Text(description)),
              if (status == 'running')
                TextButton(
                  onPressed: () => _cancelTask(taskId, appState),
                  child: const Text('取消'),
                ),
            ],
          ),
          if (progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text('${(progress * 100).toInt()}%', 
                 style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  /// 快速操作
  Widget _buildQuickActions(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速操作',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.refresh,
                    label: '刷新状态',
                    onTap: () => _refreshStatus(appState),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.restart_alt,
                    label: '重启 Gateway',
                    onTap: () => _restartGateway(appState),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.terminal,
                    label: '发送命令',
                    onTap: () => _sendCommand(appState),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.settings_remote,
                    label: '远程控制',
                    onTap: () => _openRemoteControl(appState),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // 操作方法
  void _createNewSession(AppState appState) async {
    final success = await appState.createSession(name: 'New Session');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '会话已创建' : '创建失败')),
      );
    }
  }

  void _cancelTask(String taskId, AppState appState) async {
    final success = await appState.cancelRemoteTask(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '任务已取消' : '取消失败')),
      );
    }
  }

  void _cancelAllTasks(AppState appState) async {
    final tasks = appState.remoteTasks;
    var successCount = 0;
    
    for (final task in tasks) {
      final taskId = task['id'] ?? task['taskId'];
      if (taskId != null && await appState.cancelRemoteTask(taskId)) {
        successCount++;
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消 $successCount/${tasks.length} 个任务')),
      );
    }
  }

  void _refreshStatus(AppState appState) async {
    if (appState.isRemoteConnected) {
      await appState.refreshGatewayData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已刷新')),
        );
      }
    } else {
      await appState.connectRemote();
    }
  }

  void _restartGateway(AppState appState) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重启 Gateway'),
        content: const Text('确定要重启远程 Gateway 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await appState.sendGatewayCommand('restart');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '重启命令已发送' : '发送失败')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _sendCommand(AppState appState) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送命令'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入命令...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final command = controller.text.trim();
              Navigator.pop(context);
              if (command.isNotEmpty) {
                final success = await appState.sendGatewayCommand(command);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? '命令已发送: $command' : '发送失败')),
                  );
                }
              }
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  void _openRemoteControl(AppState appState) {
    // TODO: 打开远程控制界面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('远程控制功能开发中...')),
    );
  }
}

// Gateway 连接屏幕
//
// 配置和连接到 OpenClaw Gateway

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/remote/remote_connection.dart';

/// 默认 Gateway 配置（Windows龙虾）
const _defaultGatewayUrl = 'http://100.80.206.8:18789';
const _defaultGatewayToken = '6374a3974149286117d8df733c6f20dfd7d8bed73aa9de7c';
const _defaultGatewayName = 'Windows龙虾';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isConnecting = false;
  RemoteConnectionState _connectionState = RemoteConnectionState.disconnected;
  GatewayInfo? _gatewayInfo;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final appState = context.read<AppState>();
    final connection = appState.remoteConnection;
    
    if (connection != null) {
      _urlController.text = connection.url;
      if (connection.token != null) {
        _tokenController.text = connection.token!;
      }
      setState(() {
        _connectionState = connection.state;
        _gatewayInfo = connection.gatewayInfo;
      });
      
      // 监听状态变化
      connection.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _connectionState = state;
          });
        }
      });
    } else {
      // 使用默认 Gateway 配置（Windows龙虾）
      _urlController.text = _defaultGatewayUrl;
      _tokenController.text = _defaultGatewayToken;
    }
  }

  Future<void> _connect() async {
    if (_urlController.text.isEmpty) {
      _showError('请输入 Gateway URL');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final appState = context.read<AppState>();
      final connection = RemoteConnection(
        url: _urlController.text.trim(),
        token: _tokenController.text.trim().isEmpty 
            ? null 
            : _tokenController.text.trim(),
      );

      final success = await connection.connect();
      
      if (success) {
        appState.setRemoteConnection(connection);
        final info = await connection.fetchGatewayInfo();
        setState(() {
          _connectionState = RemoteConnectionState.connected;
          _gatewayInfo = info;
        });
        _showSuccess('连接成功');
      } else {
        _showError('连接失败: ${connection.error ?? "未知错误"}');
      }
    } catch (e) {
      _showError('连接出错: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnect() {
    final appState = context.read<AppState>();
    appState.remoteConnection?.disconnect();
    appState.setRemoteConnection(null);
    setState(() {
      _connectionState = RemoteConnectionState.disconnected;
      _gatewayInfo = null;
    });
    _showSuccess('已断开连接');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateway 连接'),
        actions: [
          if (_connectionState == RemoteConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showGatewayInfo,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 连接状态卡片
          _buildStatusCard(),
          const SizedBox(height: 16),

          // URL 输入
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Gateway URL',
              hintText: 'http://192.168.1.100:3000',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            enabled: _connectionState != RemoteConnectionState.connected,
          ),
          const SizedBox(height: 16),

          // Token 输入（可选）
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Token（可选）',
              hintText: 'Bearer token',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: _connectionState != RemoteConnectionState.connected,
          ),
          const SizedBox(height: 24),

          // 连接按钮
          if (_connectionState != RemoteConnectionState.connected)
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power),
              label: Text(_isConnecting ? '连接中...' : '连接'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.power_off),
              label: const Text('断开连接'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          const SizedBox(height: 24),

          // 功能说明
          if (_connectionState == RemoteConnectionState.connected) ...[
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '已启用远程能力',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildCapabilityItem('执行远程命令', '通过 Gateway exec 执行 Shell 命令'),
            _buildCapabilityItem('远程搜索', '使用 Gateway 的 web_search'),
            _buildCapabilityItem('远程技能', '执行 Gateway 上的所有技能'),
            _buildCapabilityItem('浏览器控制', '通过 Gateway browser 控制浏览器'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_connectionState) {
      case RemoteConnectionState.connected:
        statusColor = Colors.green;
        statusText = '已连接';
        statusIcon = Icons.check_circle;
        break;
      case RemoteConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = '连接中...';
        statusIcon = Icons.pending;
        break;
      case RemoteConnectionState.error:
        statusColor = Colors.red;
        statusText = '连接错误';
        statusIcon = Icons.error;
        break;
      case RemoteConnectionState.disconnected:
        statusColor = Colors.grey;
        statusText = '未连接';
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Card(
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: _gatewayInfo != null
            ? Text('Gateway ${_gatewayInfo!.version} (${_gatewayInfo!.platform})')
            : null,
      ),
    );
  }

  Widget _buildCapabilityItem(String title, String description) {
    return ListTile(
      leading: const Icon(Icons.check, color: Colors.green),
      title: Text(title),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showGatewayInfo() {
    if (_gatewayInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gateway 信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: ${_gatewayInfo!.version}'),
            Text('平台: ${_gatewayInfo!.platform}'),
            Text('协议版本: ${_gatewayInfo!.protocolVersion}'),
            const SizedBox(height: 8),
            const Text('支持的功能:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_gatewayInfo!.features['methods'] as List?)
                ?.map((m) => Text('  • $m')) ?? [],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

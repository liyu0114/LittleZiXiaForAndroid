import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 网络诊断工具
class NetworkDiagnostics {
  /// 测试 DNS 解析
  static Future<String> testDns(String hostname) async {
    try {
      final addresses = await InternetAddress.lookup(hostname);
      if (addresses.isEmpty) {
        return '❌ DNS 解析失败: 没有找到 IP 地址';
      }
      final ips = addresses.map((addr) => addr.address).join(', ');
      return '✅ DNS 解析成功: $hostname -> $ips';
    } catch (e) {
      return '❌ DNS 解析失败: $e';
    }
  }

  /// 测试 HTTP 连接
  static Future<String> testHttpConnection(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      return '✅ HTTP 连接成功: ${response.statusCode} (${response.contentLength} bytes)';
    } on TimeoutException {
      return '❌ HTTP 连接超时';
    } on SocketException catch (e) {
      return '❌ HTTP 连接失败: ${e.message}';
    } catch (e) {
      return '❌ HTTP 连接异常: $e';
    }
  }

  /// 测试网络连接
  static Future<String> testConnectivity() async {
    final results = <String>[];
    
    // 测试 DNS
    results.add('=== DNS 测试 ===');
    results.add(await testDns('www.baidu.com'));
    results.add(await testDns('open.bigmodel.cn'));
    results.add('');
    
    // 测试 HTTP
    results.add('=== HTTP 测试 ===');
    results.add(await testHttpConnection('https://www.baidu.com'));
    results.add(await testHttpConnection('https://open.bigmodel.cn'));
    
    return results.join('\n');
  }
}

/// 网络诊断对话框
class NetworkDiagnosticsDialog extends StatefulWidget {
  const NetworkDiagnosticsDialog({super.key});

  @override
  State<NetworkDiagnosticsDialog> createState() => _NetworkDiagnosticsDialogState();
}

class _NetworkDiagnosticsDialogState extends State<NetworkDiagnosticsDialog> {
  String _result = '正在诊断...';
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _result = '正在诊断网络连接...\n';
    });

    final result = await NetworkDiagnostics.testConnectivity();

    if (mounted) {
      setState(() {
        _result = result;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.network_check),
          SizedBox(width: 8),
          Text('网络诊断'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRunning)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在测试...'),
                ],
              ),
            const SizedBox(height: 12),
            SelectableText(
              _result,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isRunning)
          TextButton.icon(
            onPressed: _runDiagnostics,
            icon: const Icon(Icons.refresh),
            label: const Text('重新诊断'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

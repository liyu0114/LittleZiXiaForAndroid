// Shell 命令服务
//
// 执行系统 Shell 命令（需要 ADB）

import 'package:flutter/foundation.dart';
import 'dart:io';

class ShellService extends ChangeNotifier {
  bool _adbAuthorized = false;

  bool get adbAuthorized => _adbAuthorized;

  /// 授权 ADB
  void authorizeAdb() {
    _adbAuthorized = true;
    notifyListeners();
    debugPrint('[Shell] ADB 已授权');
  }

  /// 撤销 ADB 授权
  void revokeAdb() {
    _adbAuthorized = false;
    notifyListeners();
    debugPrint('[Shell] ADB 授权已撤销');
  }

  /// 执行命令
  Future<ShellResult> execute(String command, {List<String> args = const []}) async {
    if (!_adbAuthorized) {
      return ShellResult(
        success: false,
        output: '',
        error: 'ADB 未授权',
      );
    }

    try {
      debugPrint('[Shell] 执行命令: $command ${args.join(' ')}');

      final result = await Process.run(
        command,
        args,
        runInShell: true,
      );

      final output = result.stdout.toString();
      final error = result.stderr.toString();
      final exitCode = result.exitCode;

      debugPrint('[Shell] 命令完成 (exit code: $exitCode)');

      return ShellResult(
        success: exitCode == 0,
        output: output,
        error: error,
        exitCode: exitCode,
      );
    } catch (e) {
      debugPrint('[Shell] 命令执行失败: $e');
      return ShellResult(
        success: false,
        output: '',
        error: e.toString(),
      );
    }
  }

  /// 截屏
  Future<String?> screenshot({String? savePath}) async {
    final result = await execute('screencap', args: ['-p', savePath ?? '/sdcard/screenshot.png']);
    return result.success ? (savePath ?? '/sdcard/screenshot.png') : null;
  }

  /// 列出文件
  Future<List<String>> listFiles(String path) async {
    final result = await execute('ls', args: ['-1', path]);
    if (result.success) {
      return result.output.split('\n').where((line) => line.isNotEmpty).toList();
    }
    return [];
  }
}

class ShellResult {
  final bool success;
  final String output;
  final String error;
  final int? exitCode;

  ShellResult({
    required this.success,
    required this.output,
    required this.error,
    this.exitCode,
  });

  @override
  String toString() {
    if (success) {
      return output;
    } else {
      return 'Error: $error';
    }
  }
}

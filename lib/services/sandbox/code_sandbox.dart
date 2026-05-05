// 代码执行沙盒服务
//
// 用于安全执行用户代码

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 代码执行结果
class CodeResult {
  final bool success;
  final String? output;
  final String? error;
  final int executionTimeMs;
  
  CodeResult({
    required this.success,
    this.output,
    this.error,
    this.executionTimeMs = 0,
  });
}

/// 代码沙盒
class CodeSandbox extends ChangeNotifier {
  static const int TIMEOUT_MS = 5000;
  static const int MAX_OUTPUT_LENGTH = 10000;
  
  bool _isRunning = false;
  int _executionCount = 0;
  
  bool get isRunning => _isRunning;
  int get executionCount => _executionCount;
  
  /// 执行代码
  /// 注意：这只是演示，实际需要使用安全的解释器
  Future<CodeResult> execute(String language, String code) async {
    if (_isRunning) {
      return CodeResult(
        success: false,
        error: '已有代码在执行中',
      );
    }
    
    _isRunning = true;
    _executionCount++;
    notifyListeners();
    
    final sw = Stopwatch()..start();
    
    try {
      // 简单演示：返回代码信息
      // TODO: 实际应该使用安全的解释器执行
      await Future.delayed(Duration(milliseconds: 100));
      
      sw.stop();
      
      return CodeResult(
        success: true,
        output: '[$language] 代码执行完成\n---\ncode length: ${code.length}',
        executionTimeMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return CodeResult(
        success: false,
        error: e.toString(),
        executionTimeMs: sw.elapsedMilliseconds,
      );
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }
  
  /// 停止执行
  void stop() {
    _isRunning = false;
    notifyListeners();
  }
}
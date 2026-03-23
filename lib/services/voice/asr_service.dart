// 语音识别服务（ASR）
//
// 使用 Android 原生 SpeechRecognizer API

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ASRService extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.openclaw_app/speech');

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastResult = '';
  String _error = '';

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastResult => _lastResult;
  String get error => _error;

  ASRService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      _isInitialized = result == true;
      notifyListeners();
      debugPrint('[ASR] 初始化: $_isInitialized');
    } catch (e) {
      debugPrint('[ASR] 初始化失败: $e');
      _error = e.toString();
    }
  }

  /// 开始监听
  Future<String?> listen() async {
    if (!_isInitialized) {
      debugPrint('[ASR] 未初始化');
      return null;
    }

    if (_isListening) {
      debugPrint('[ASR] 已在监听中');
      return null;
    }

    try {
      _isListening = true;
      _lastResult = '';
      _error = '';
      notifyListeners();

      debugPrint('[ASR] 开始监听...');
      final result = await _channel.invokeMethod('listen');

      _lastResult = result?.toString() ?? '';
      debugPrint('[ASR] 识别结果: $_lastResult');

      _isListening = false;
      notifyListeners();

      return _lastResult;
    } catch (e) {
      debugPrint('[ASR] 监听失败: $e');
      _error = e.toString();
      _isListening = false;
      notifyListeners();
      return null;
    }
  }

  /// 停止监听
  Future<void> stop() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod('stop');
      _isListening = false;
      notifyListeners();
      debugPrint('[ASR] 停止监听');
    } catch (e) {
      debugPrint('[ASR] 停止失败: $e');
    }
  }

  /// 销毁
  Future<void> destroy() async {
    try {
      await _channel.invokeMethod('destroy');
      _isInitialized = false;
      _isListening = false;
      notifyListeners();
      debugPrint('[ASR] 已销毁');
    } catch (e) {
      debugPrint('[ASR] 销毁失败: $e');
    }
  }

  @override
  void dispose() {
    destroy();
    super.dispose();
  }
}

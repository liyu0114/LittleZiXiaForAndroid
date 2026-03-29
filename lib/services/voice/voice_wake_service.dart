// 语音唤醒服务
//
// 通过语音唤醒词激活助手

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音唤醒服务
class VoiceWakeService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  String _status = '未初始化';

  // 唤醒词列表
  final List<String> _wakeWords = [
    '嘿紫霞',
    '小紫霞',
    '紫霞',
    'hey 紫霞',
    'hey zixia',
  ];

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get status => _status;

  /// 初始化
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceWake] 错误: $error');
          _status = '错误: ${error.errorMsg}';
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('[VoiceWake] 状态: $status');
          _status = status;
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
          notifyListeners();
        },
      );

      if (_isInitialized) {
        debugPrint('[VoiceWake] 初始化成功');
        _status = '已就绪';
      } else {
        debugPrint('[VoiceWake] 初始化失败');
        _status = '初始化失败';
      }

      notifyListeners();
      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceWake] 初始化异常: $e');
      _status = '异常: $e';
      notifyListeners();
      return false;
    }
  }

  /// 开始监听唤醒词
  Future<void> startListening({Function(String)? onWake}) async {
    if (!_isInitialized) {
      debugPrint('[VoiceWake] 未初始化');
      return;
    }

    if (_isListening) {
      debugPrint('[VoiceWake] 已在监听中');
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          debugPrint('[VoiceWake] 识别: $_lastWords');
          notifyListeners();

          // 检查是否包含唤醒词
          if (_containsWakeWord(_lastWords)) {
            debugPrint('[VoiceWake] 🎉 检测到唤醒词！');
            _status = '已唤醒';
            notifyListeners();

            // 回调
            if (onWake != null) {
              onWake(_lastWords);
            }

            // 停止监听
            stopListening();
          }
        },
        listenFor: Duration(seconds: 30),  // 监听 30 秒
        pauseFor: Duration(seconds: 3),    // 3 秒无声音暂停
        partialResults: true,              // 部分结果
        cancelOnError: true,               // 错误时取消
        localeId: 'zh_CN',                 // 中文
      );

      _isListening = true;
      _status = '监听中...';
      notifyListeners();
    } catch (e) {
      debugPrint('[VoiceWake] 监听失败: $e');
      _status = '监听失败: $e';
      notifyListeners();
    }
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      _status = '已停止';
      notifyListeners();
    } catch (e) {
      debugPrint('[VoiceWake] 停止失败: $e');
    }
  }

  /// 检查是否包含唤醒词
  bool _containsWakeWord(String text) {
    final lowerText = text.toLowerCase();
    return _wakeWords.any((word) => lowerText.contains(word.toLowerCase()));
  }

  /// 添加自定义唤醒词
  void addWakeWord(String word) {
    if (!_wakeWords.contains(word)) {
      _wakeWords.add(word);
    }
  }

  /// 移除唤醒词
  void removeWakeWord(String word) {
    _wakeWords.remove(word);
  }

  /// 获取所有唤醒词
  List<String> get wakeWords => List.unmodifiable(_wakeWords);

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

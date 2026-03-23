// 语音合成服务（TTS）
//
// 让小紫霞能够语音回复

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;  // 语速（0.0-1.0）

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;

  TTSService() {
    _init();
  }

  Future<void> _init() async {
    try {
      // 设置语言
      await _flutterTts.setLanguage('zh-CN');

      // 设置音量（0.0-1.0）
      await _flutterTts.setVolume(_volume);

      // 设置音调（0.5-2.0）
      await _flutterTts.setPitch(_pitch);

      // 设置语速（0.0-1.0）
      await _flutterTts.setSpeechRate(_rate);

      // 监听开始播放
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
        debugPrint('[TTS] 开始播放');
      });

      // 监听播放完成
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('[TTS] 播放完成');
      });

      // 监听播放取消
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('[TTS] 播放取消');
      });

      // 监听错误
      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('[TTS] 错误: $message');
      });

      _isInitialized = true;
      notifyListeners();
      debugPrint('[TTS] 初始化成功');
    } catch (e) {
      debugPrint('[TTS] 初始化失败: $e');
    }
  }

  /// 播放语音
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      debugPrint('[TTS] 未初始化');
      return;
    }

    if (text.trim().isEmpty) {
      debugPrint('[TTS] 文本为空');
      return;
    }

    try {
      // 如果正在播放，先停止
      if (_isSpeaking) {
        await stop();
      }

      debugPrint('[TTS] 播放: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] 播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
      debugPrint('[TTS] 停止播放');
    } catch (e) {
      debugPrint('[TTS] 停止失败: $e');
    }
  }

  /// 暂停播放（iOS only）
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _isSpeaking = false;
      notifyListeners();
      debugPrint('[TTS] 暂停播放');
    } catch (e) {
      debugPrint('[TTS] 暂停失败: $e');
    }
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) return;

    _volume = volume;
    await _flutterTts.setVolume(volume);
    notifyListeners();
    debugPrint('[TTS] 音量: $volume');
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    if (pitch < 0.5 || pitch > 2.0) return;

    _pitch = pitch;
    await _flutterTts.setPitch(pitch);
    notifyListeners();
    debugPrint('[TTS] 音调: $pitch');
  }

  /// 设置语速
  Future<void> setRate(double rate) async {
    if (rate < 0.0 || rate > 1.0) return;

    _rate = rate;
    await _flutterTts.setSpeechRate(rate);
    notifyListeners();
    debugPrint('[TTS] 语速: $rate');
  }

  /// 获取可用语音
  Future<List<Map>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<Map>.from(voices);
    } catch (e) {
      debugPrint('[TTS] 获取语音列表失败: $e');
      return [];
    }
  }

  /// 设置语音
  Future<void> setVoice(Map voice) async {
    try {
      await _flutterTts.setVoice(voice.cast<String, String>());
      debugPrint('[TTS] 设置语音: $voice');
    } catch (e) {
      debugPrint('[TTS] 设置语音失败: $e');
    }
  }

  @override
  void dispose() {
    stop();
    _flutterTts.stop();
    super.dispose();
  }
}

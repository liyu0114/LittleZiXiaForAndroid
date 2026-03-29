// 音量控制服务
//
// 媒体、铃声、通知音量控制

import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

/// 音量类型
enum VolumeType {
  media,     // 媒体音量
  ringtone,  // 铃声音量
  notification, // 通知音量
  alarm,     // 闹钟音量
}

/// 音量控制服务
class VolumeControlService extends ChangeNotifier {
  double _mediaVolume = 0.5;
  double _ringtoneVolume = 0.5;
  double _notificationVolume = 0.5;
  bool _isMuted = false;

  double get mediaVolume => _mediaVolume;
  double get ringtoneVolume => _ringtoneVolume;
  double get notificationVolume => _notificationVolume;
  bool get isMuted => _isMuted;

  /// 初始化
  Future<void> initialize() async {
    try {
      await VolumeController().listener((volume) {
        _mediaVolume = volume;
        notifyListeners();
      });

      _mediaVolume = await VolumeController().getVolume();
      debugPrint('[Volume] 当前音量: $_mediaVolume');
      
      notifyListeners();
    } catch (e) {
      debugPrint('[Volume] 初始化失败: $e');
    }
  }

  /// 设置媒体音量 (0.0 - 1.0)
  Future<void> setMediaVolume(double value) async {
    try {
      final volume = value.clamp(0.0, 1.0);
      VolumeController().setVolume(volume);  // 不 await，因为返回 void
      _mediaVolume = volume;
      _isMuted = volume == 0.0;
      
      debugPrint('[Volume] 设置音量: $volume');
      notifyListeners();
    } catch (e) {
      debugPrint('[Volume] 设置音量失败: $e');
    }
  }

  /// 增加音量
  Future<void> increaseVolume({double step = 0.1}) async {
    await setMediaVolume(_mediaVolume + step);
  }

  /// 降低音量
  Future<void> decreaseVolume({double step = 0.1}) async {
    await setMediaVolume(_mediaVolume - step);
  }

  /// 静音
  Future<void> mute() async {
    await setMediaVolume(0.0);
    _isMuted = true;
  }

  /// 取消静音
  Future<void> unmute({double restoreVolume = 0.5}) async {
    await setMediaVolume(restoreVolume);
    _isMuted = false;
  }

  /// 切换静音
  Future<void> toggleMute() async {
    if (_isMuted) {
      await unmute();
    } else {
      await mute();
    }
  }

  /// 最大音量
  Future<void> maxVolume() async {
    await setMediaVolume(1.0);
  }

  /// 获取音量百分比
  int getVolumePercentage() {
    return (_mediaVolume * 100).round();
  }

  /// 获取音量描述
  String getVolumeDescription() {
    final percentage = getVolumePercentage();
    
    if (percentage == 0) return '静音';
    if (percentage < 20) return '很低';
    if (percentage < 40) return '较低';
    if (percentage < 60) return '适中';
    if (percentage < 80) return '较高';
    return '很高';
  }

  @override
  void dispose() {
    VolumeController().removeListener();
    super.dispose();
  }
}

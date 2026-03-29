// 活动识别服务
//
// 检测用户当前的运动状态

import 'package:flutter/foundation.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';

/// 活动识别服务
class ActivityRecognitionService extends ChangeNotifier {
  Stream<ActivityEvent>? _activityStream;
  ActivityEvent? _currentActivity;

  ActivityEvent? get currentActivity => _currentActivity;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 检查权限
      // Note: Android 需要活动识别权限

      // 监听活动变化
      _activityStream = ActivityRecognitionFlutter.activityStream;
      _activityStream?.listen((ActivityEvent event) {
        _currentActivity = event;
        notifyListeners();
        debugPrint('[Activity] 活动变化: ${event.type}, 置信度: ${event.confidence}');
      });

      debugPrint('[ActivityRecognition] 初始化完成');
    } catch (e) {
      debugPrint('[ActivityRecognition] 初始化失败: $e');
    }
  }

  /// 获取活动描述
  String getActivityDescription(ActivityType type) {
    switch (type) {
      case ActivityType.IN_VEHICLE:
        return '🚗 乘车中';
      case ActivityType.ON_BICYCLE:
        return '🚴 骑行中';
      case ActivityType.ON_FOOT:
        return '🚶 步行中';
      case ActivityType.RUNNING:
        return '🏃 跑步中';
      case ActivityType.STILL:
        return '🧘 静止';
      case ActivityType.TILTING:
        return '📱 移动设备';
      case ActivityType.WALKING:
        return '🚶 走路';
      case ActivityType.UNKNOWN:
      default:
        return '❓ 未知';
    }
  }

  /// 获取活动信息
  String getActivityInfo() {
    if (_currentActivity == null) {
      return '⚠️ 未检测到活动信息';
    }

    final description = getActivityDescription(_currentActivity!.type);
    final confidence = (_currentActivity!.confidence * 100).toStringAsFixed(0);

    // 提示
    String tip = '';
    switch (_currentActivity!.type) {
      case ActivityType.IN_VEHICLE:
        tip = '提示: 乘车时注意安全';
        break;
      case ActivityType.RUNNING:
        tip = '加油！继续跑！';
        break;
      case ActivityType.ON_FOOT:
      case ActivityType.WALKING:
        tip = '散步有益健康';
        break;
      case ActivityType.STILL:
        tip = '久坐不利于健康，起来活动一下吧';
        break;
      default:
        break;
    }

    return '''🏃 运动状态

状态: $description
置信度: $confidence%

$tip''';
  }

  /// 检查是否在运动
  bool get isInVehicle => _currentActivity?.type == ActivityType.IN_VEHICLE;
  bool get isRunning => _currentActivity?.type == ActivityType.RUNNING;
  bool get isWalking =>
      _currentActivity?.type == ActivityType.WALKING ||
      _currentActivity?.type == ActivityType.ON_FOOT;
  bool get isStill => _currentActivity?.type == ActivityType.STILL;

  @override
  void dispose() {
    _activityStream = null;
    super.dispose();
  }
}

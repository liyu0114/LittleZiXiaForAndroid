// 通知服务
//
// 发送本地系统通知

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[Notification] 用户点击通知: ${response.payload}');
      },
    );

    _isInitialized = true;
    notifyListeners();
    debugPrint('[Notification] 通知服务已初始化');
  }

  /// 发送通知
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'little_zixia_channel',
      '小紫霞通知',
      channelDescription: '小紫霞的消息通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );

    debugPrint('[Notification] 已发送通知: $title - $body');
  }

  /// 发送定时通知
  Future<void> schedule({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'little_zixia_scheduled',
      '小紫霞定时通知',
      channelDescription: '小紫霞的定时提醒',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // 简化版本：使用延迟而不是时区
    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) {
      throw ArgumentError('定时时间不能是过去的时间');
    }

    // 延迟发送
    Future.delayed(delay, () async {
      await show(title: title, body: body, payload: payload);
    });

    debugPrint('[Notification] 已安排定时通知: $title - $scheduledDate');
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('[Notification] 已取消所有通知');
  }

  /// 获取待发送的通知列表
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

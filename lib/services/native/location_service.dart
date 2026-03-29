// 位置服务
//
// 获取设备的 GPS 位置信息

import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService extends ChangeNotifier {
  Position? _lastPosition;
  bool _isTracking = false;
  Stream<Position>? _positionStream;

  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  /// 检查位置权限
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 获取当前位置
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('[Location] 没有位置权限');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastPosition = position;
      notifyListeners();

      debugPrint('[Location] 当前位置: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[Location] 获取位置失败: $e');
      return null;
    }
  }

  /// 开始追踪位置
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermission();
    if (!hasPermission) {
      debugPrint('[Location] 没有位置权限');
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings);
    _positionStream!.listen((Position position) {
      _lastPosition = position;
      notifyListeners();
      debugPrint('[Location] 位置更新: ${position.latitude}, ${position.longitude}');
    });

    _isTracking = true;
    notifyListeners();
    debugPrint('[Location] 开始追踪位置');
  }

  /// 停止追踪位置
  void stopTracking() {
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
    debugPrint('[Location] 停止追踪位置');
  }

  /// 获取位置信息（人类可读）
  Future<String> getLocationInfo() async {
    final position = await getCurrentPosition();
    if (position == null) {
      return '无法获取位置信息';
    }

    return '📍 位置信息\n'
        '纬度: ${position.latitude.toStringAsFixed(6)}\n'
        '经度: ${position.longitude.toStringAsFixed(6)}\n'
        '海拔: ${position.altitude.toStringAsFixed(2)} 米\n'
        '精度: ${position.accuracy.toStringAsFixed(2)} 米\n'
        '速度: ${position.speed.toStringAsFixed(2)} 米/秒\n'
        '时间: ${DateTime.fromMillisecondsSinceEpoch(position.timestamp!.millisecondsSinceEpoch)}';
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

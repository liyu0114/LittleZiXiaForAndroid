// 传感器服务
//
// 加速度计、陀螺仪、磁力计等

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

/// 传感器数据
class SensorData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  SensorData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get magnitude => sqrt(x * x + y * y + z * z);

  @override
  String toString() => 'SensorData(x: $x, y: $y, z: $z, mag: $magnitude)';
}

/// 传感器服务
class SensorService extends ChangeNotifier {
  // 加速度计
  SensorData? _accelerometerData;
  StreamSubscription? _accelerometerSubscription;

  // 陀螺仪
  SensorData? _gyroscopeData;
  StreamSubscription? _gyroscopeSubscription;

  // 磁力计
  SensorData? _magnetometerData;
  StreamSubscription? _magnetometerSubscription;

  // 用户加速度（去除重力）
  SensorData? _userAccelerometerData;
  StreamSubscription? _userAccelerometerSubscription;

  SensorData? get accelerometerData => _accelerometerData;
  SensorData? get gyroscopeData => _gyroscopeData;
  SensorData? get magnetometerData => _magnetometerData;
  SensorData? get userAccelerometerData => _userAccelerometerData;

  /// 开始监听加速度计
  void startAccelerometer({Duration interval = const Duration(milliseconds: 100)}) {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      _accelerometerData = SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });
    debugPrint('[Sensor] 开始监听加速度计');
  }

  /// 停止监听加速度计
  void stopAccelerometer() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    debugPrint('[Sensor] 停止监听加速度计');
  }

  /// 开始监听陀螺仪
  void startGyroscope({Duration interval = const Duration(milliseconds: 100)}) {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      _gyroscopeData = SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });
    debugPrint('[Sensor] 开始监听陀螺仪');
  }

  /// 停止监听陀螺仪
  void stopGyroscope() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    debugPrint('[Sensor] 停止监听陀螺仪');
  }

  /// 开始监听磁力计
  void startMagnetometer({Duration interval = const Duration(milliseconds: 100)}) {
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      _magnetometerData = SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });
    debugPrint('[Sensor] 开始监听磁力计');
  }

  /// 停止监听磁力计
  void stopMagnetometer() {
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    debugPrint('[Sensor] 停止监听磁力计');
  }

  /// 开始监听用户加速度
  void startUserAccelerometer({Duration interval = const Duration(milliseconds: 100)}) {
    _userAccelerometerSubscription?.cancel();
    _userAccelerometerSubscription = userAccelerometerEventStream().listen((event) {
      _userAccelerometerData = SensorData(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });
    debugPrint('[Sensor] 开始监听用户加速度');
  }

  /// 停止监听用户加速度
  void stopUserAccelerometer() {
    _userAccelerometerSubscription?.cancel();
    _userAccelerometerSubscription = null;
    debugPrint('[Sensor] 停止监听用户加速度');
  }

  /// 检测摇晃
  bool detectShake({double threshold = 20.0}) {
    if (_userAccelerometerData == null) return false;
    return _userAccelerometerData!.magnitude > threshold;
  }

  /// 获取设备倾斜角度（度）
  double? getDeviceTilt() {
    if (_accelerometerData == null) return null;

    // 计算倾斜角度
    final x = _accelerometerData!.x;
    final y = _accelerometerData!.y;
    final z = _accelerometerData!.z;

    // 俯仰角（前后倾斜）
    final pitch = atan2(x, sqrt(y * y + z * z)) * 180 / pi;

    // 翻滚角（左右倾斜）
    final roll = atan2(y, sqrt(x * x + z * z)) * 180 / pi;

    return pitch.abs() > roll.abs() ? pitch : roll;
  }

  /// 获取所有传感器数据
  String getAllSensorData() {
    final buffer = StringBuffer();
    buffer.writeln('📱 传感器数据');
    buffer.writeln();

    if (_accelerometerData != null) {
      buffer.writeln('加速度计:');
      buffer.writeln('  X: ${_accelerometerData!.x.toStringAsFixed(2)} m/s²');
      buffer.writeln('  Y: ${_accelerometerData!.y.toStringAsFixed(2)} m/s²');
      buffer.writeln('  Z: ${_accelerometerData!.z.toStringAsFixed(2)} m/s²');
      buffer.writeln('  合力: ${_accelerometerData!.magnitude.toStringAsFixed(2)} m/s²');
      buffer.writeln();
    }

    if (_gyroscopeData != null) {
      buffer.writeln('陀螺仪:');
      buffer.writeln('  X: ${_gyroscopeData!.x.toStringAsFixed(2)} rad/s');
      buffer.writeln('  Y: ${_gyroscopeData!.y.toStringAsFixed(2)} rad/s');
      buffer.writeln('  Z: ${_gyroscopeData!.z.toStringAsFixed(2)} rad/s');
      buffer.writeln();
    }

    if (_magnetometerData != null) {
      buffer.writeln('磁力计:');
      buffer.writeln('  X: ${_magnetometerData!.x.toStringAsFixed(2)} μT');
      buffer.writeln('  Y: ${_magnetometerData!.y.toStringAsFixed(2)} μT');
      buffer.writeln('  Z: ${_magnetometerData!.z.toStringAsFixed(2)} μT');
      buffer.writeln();
    }

    final tilt = getDeviceTilt();
    if (tilt != null) {
      buffer.writeln('设备倾斜: ${tilt.toStringAsFixed(1)}°');
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    stopAccelerometer();
    stopGyroscope();
    stopMagnetometer();
    stopUserAccelerometer();
    super.dispose();
  }
}

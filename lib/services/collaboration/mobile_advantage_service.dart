/// 移动设备优势服务
/// 
/// 利用移动设备特有硬件：
/// - 传感器（加速度计、陀螺仪、磁力计、气压计）
/// - 位置服务（GPS、网络定位）
/// - 健康数据（步数、心率、睡眠）
/// - 生物识别（指纹、面容）
/// - 蓝牙/NFC/UWB

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

/// 移动设备能力
class MobileCapabilities {
  final bool hasAccelerometer;
  final bool hasGyroscope;
  final bool hasMagnetometer;
  final bool hasGPS;
  final bool hasCompass;
  final bool hasPedometer;
  final bool hasBluetooth;
  final bool hasNFC;
  final bool hasFingerprint;
  final bool hasFaceID;

  MobileCapabilities({
    required this.hasAccelerometer,
    required this.hasGyroscope,
    required this.hasMagnetometer,
    required this.hasGPS,
    required this.hasCompass,
    required this.hasPedometer,
    required this.hasBluetooth,
    required this.hasNFC,
    required this.hasFingerprint,
    required this.hasFaceID,
  });

  static Future<MobileCapabilities> detect() async {
    return MobileCapabilities(
      hasAccelerometer: await accelerometerEventStream().isEmpty == false,
      hasGyroscope: await gyroscopeEventStream().isEmpty == false,
      hasMagnetometer: await magnetometerEventStream().isEmpty == false,
      hasGPS: await Geolocator.isLocationServiceAvailable(),
      hasCompass: await FlutterCompass.events?.first != null,
      hasPedometer: true, // 需要实际测试
      hasBluetooth: true, // 需要 permission
      hasNFC: false, // 需要 NFC 插件
      hasFingerprint: true, // 需要 local_auth
      hasFaceID: true, // 需要 local_auth
    );
  }
}

/// 位置数据
class LocationData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.accuracy = 0,
    this.speed = 0,
    this.heading = 0,
    required this.timestamp,
  });

  String get formatted => '$latitude, $longitude';
  
  String get googleMapsUrl => 'https://www.google.com/maps?q=$latitude,$longitude';
  
  String get appleMapsUrl => 'https://maps.apple.com/?q=$latitude,$longitude';

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 健康数据
class HealthData {
  final int steps;
  final int? heartRate;
  final int? sleepMinutes;
  final DateTime timestamp;

  HealthData({
    required this.steps,
    this.heartRate,
    this.sleepMinutes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'heartRate': heartRate,
    'sleepMinutes': sleepMinutes,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// 移动设备优势服务
class MobileAdvantageService extends ChangeNotifier {
  // 位置
  LocationData? _currentLocation;
  StreamSubscription? _locationSubscription;

  // 计步器
  HealthData? _healthData;
  StreamSubscription? _stepSubscription;

  // 指南针
  double? _heading;
  StreamSubscription? _compassSubscription;

  // 电池
  int _batteryLevel = 0;
  bool _isCharging = false;
  StreamSubscription? _batterySubscription;

  // 网络状态
  List<ConnectivityResult> _connectivity = [];
  StreamSubscription? _connectivitySubscription;

  // 摇晃检测
  bool _isShaking = false;
  StreamSubscription? _accelerometerSubscription;

  // Getters
  LocationData? get currentLocation => _currentLocation;
  HealthData? get healthData => _healthData;
  double? get heading => _heading;
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  List<ConnectivityResult> get connectivity => _connectivity;
  bool get isShaking => _isShaking;

  /// 初始化所有服务
  Future<void> initialize() async {
    debugPrint('[MobileAdvantage] 初始化移动设备优势服务');

    // 检测设备能力
    final capabilities = await MobileCapabilities.detect();
    debugPrint('[MobileAdvantage] 设备能力: $capabilities');

    // 启动服务
    await _startLocationService();
    await _startPedometerService();
    _startCompassService();
    _startBatteryService();
    _startConnectivityService();
    _startShakeDetection();

    debugPrint('[MobileAdvantage] 所有服务已启动');
  }

  /// 启动位置服务
  Future<void> _startLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[MobileAdvantage] 位置服务未启用');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[MobileAdvantage] 位置权限被拒绝');
        return;
      }
    }

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 移动 10 米更新一次
      ),
    ).listen((Position position) {
      _currentLocation = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });

    debugPrint('[MobileAdvantage] 位置服务已启动');
  }

  /// 启动计步器服务
  Future<void> _startPedometerService() async {
    try {
      // 使用 pedometer 插件
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _healthData = HealthData(
            steps: event.steps,
            timestamp: DateTime.now(),
          );
          notifyListeners();
        },
        onError: (error) {
          debugPrint('[MobileAdvantage] 计步器错误: $error');
        },
      );
      debugPrint('[MobileAdvantage] 计步器服务已启动');
    } catch (e) {
      debugPrint('[MobileAdvantage] 计步器不可用: $e');
    }
  }

  /// 启动指南针服务
  void _startCompassService() {
    try {
      _compassSubscription = FlutterCompass.events?.listen(
        (CompassEvent event) {
          _heading = event.heading;
          notifyListeners();
        },
      );
      debugPrint('[MobileAdvantage] 指南针服务已启动');
    } catch (e) {
      debugPrint('[MobileAdvantage] 指南针不可用: $e');
    }
  }

  /// 启动电池服务
  Future<void> _startBatteryService() async {
    try {
      final battery = Battery();
      _batteryLevel = await battery.batteryLevel;
      _isCharging = await battery.isInBatterySaveMode;

      _batterySubscription = battery.onBatteryStateChanged.listen(
        (BatteryState state) async {
          _batteryLevel = await battery.batteryLevel;
          _isCharging = state == BatteryState.charging;
          notifyListeners();
        },
      );
      debugPrint('[MobileAdvantage] 电池服务已启动');
    } catch (e) {
      debugPrint('[MobileAdvantage] 电池服务不可用: $e');
    }
  }

  /// 启动网络状态服务
  void _startConnectivityService() {
    try {
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> result) {
        _connectivity = result;
        notifyListeners();
      });
      debugPrint('[MobileAdvantage] 网络状态服务已启动');
    } catch (e) {
      debugPrint('[MobileAdvantage] 网络状态服务不可用: $e');
    }
  }

  /// 启动摇晃检测
  void _startShakeDetection() {
    _accelerometerSubscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z);
        final wasShaking = _isShaking;
        _isShaking = magnitude > 20; // 阈值可调

        if (_isShaking && !wasShaking) {
          debugPrint('[MobileAdvantage] 检测到摇晃');
          onShakeDetected();
        }
      },
    );
  }

  /// 摇晃回调（可重写）
  void onShakeDetected() {
    // 默认行为：刷新数据
    debugPrint('[MobileAdvantage] 摇晃触发刷新');
    notifyListeners();
  }

  /// 获取完整状态
  Map<String, dynamic> get fullStatus {
    return {
      'location': _currentLocation?.toJson(),
      'health': _healthData?.toJson(),
      'heading': _heading,
      'battery': {
        'level': _batteryLevel,
        'isCharging': _isCharging,
      },
      'connectivity': _connectivity.map((c) => c.name).toList(),
      'isShaking': _isShaking,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 生成上下文摘要
  String generateContextSummary() {
    final buffer = StringBuffer();
    
    buffer.writeln('📱 移动设备状态');
    buffer.writeln('时间: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln();

    if (_currentLocation != null) {
      buffer.writeln('📍 位置: ${_currentLocation!.formatted}');
      if (_currentLocation!.speed > 0) {
        buffer.writeln('   速度: ${(_currentLocation!.speed * 3.6).toStringAsFixed(1)} km/h');
      }
    }

    if (_healthData != null) {
      buffer.writeln('🏃 今日步数: ${_healthData!.steps}');
    }

    if (_heading != null) {
      buffer.writeln('🧭 方向: ${_heading!.toStringAsFixed(0)}°');
    }

    buffer.writeln('🔋 电池: $_batteryLevel% ${_isCharging ? '⚡充电中' : ''}');

    if (_connectivity.isNotEmpty) {
      buffer.writeln('📶 网络: ${_connectivity.map((c) => c.name).join(", ")}');
    }

    return buffer.toString();
  }

  /// 清理资源
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stepSubscription?.cancel();
    _compassSubscription?.cancel();
    _batterySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }
}

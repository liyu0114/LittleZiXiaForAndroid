// 移动端特有功能 - 硬件服务
//
// 震动、电池、网络状态

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 硬件服务
class HardwareService extends ChangeNotifier {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  // 电池状态
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;

  // 网络状态
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  List<ConnectivityResult> get connectionStatus => _connectionStatus;

  bool get isCharging => _batteryState == BatteryState.charging;
  bool get isLowBattery => _batteryLevel < 20;
  bool get isConnected => !_connectionStatus.contains(ConnectivityResult.none);

  /// 初始化
  Future<void> initialize() async {
    // 获取初始状态
    await _updateBatteryStatus();
    await _updateConnectionStatus();

    // 监听电池变化
    _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
      _updateBatteryLevel();
      notifyListeners();
    });

    // 监听网络变化
    _connectivity.onConnectivityChanged.listen((results) {
      _connectionStatus = results;
      notifyListeners();
    });

    debugPrint('[Hardware] 初始化完成');
  }

  /// 更新电池电量
  Future<void> _updateBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      debugPrint('[Hardware] 获取电池电量失败: $e');
    }
  }

  /// 更新电池状态
  Future<void> _updateBatteryStatus() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
    } catch (e) {
      debugPrint('[Hardware] 获取电池状态失败: $e');
    }
  }

  /// 更新网络状态
  Future<void> _updateConnectionStatus() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('[Hardware] 获取网络状态失败: $e');
    }
  }

  /// 获取电池信息
  Future<String> getBatteryInfo() async {
    await _updateBatteryStatus();

    String stateStr;
    switch (_batteryState) {
      case BatteryState.charging:
        stateStr = '充电中 ⚡';
        break;
      case BatteryState.discharging:
        stateStr = '放电中 🔋';
        break;
      case BatteryState.full:
        stateStr = '已充满 ✅';
        break;
      default:
        stateStr = '未知';
    }

    String warning = '';
    if (_batteryLevel < 20 && !isCharging) {
      warning = '\n\n⚠️ 电量较低，建议充电';
    }

    return '''🔋 电池状态

电量: $_batteryLevel%
状态: $stateStr
$warning''';
  }

  /// 获取网络信息
  Future<String> getNetworkInfo() async {
    await _updateConnectionStatus();

    if (!isConnected) {
      return '❌ 无网络连接';
    }

    final connections = <String>[];
    for (final result in _connectionStatus) {
      switch (result) {
        case ConnectivityResult.wifi:
          connections.add('WiFi 📶');
          break;
        case ConnectivityResult.mobile:
          connections.add('移动数据 📱');
          break;
        case ConnectivityResult.ethernet:
          connections.add('以太网 🔌');
          break;
        case ConnectivityResult.bluetooth:
          connections.add('蓝牙 📻');
          break;
        default:
          connections.add('其他');
      }
    }

    return '''🌐 网络状态

连接类型: ${connections.join(', ')}
状态: 已连接 ✅''';
  }

  /// 震动反馈
  Future<void> vibrate({String type = 'light'}) async {
    try {
      switch (type) {
        case 'light':
          HapticFeedback.lightImpact();
          break;
        case 'medium':
          HapticFeedback.mediumImpact();
          break;
        case 'heavy':
          HapticFeedback.heavyImpact();
          break;
        case 'selection':
          HapticFeedback.selectionClick();
          break;
        case 'vibrate':
          HapticFeedback.vibrate();
          break;
        default:
          HapticFeedback.lightImpact();
      }
      debugPrint('[Hardware] 震动反馈: $type');
    } catch (e) {
      debugPrint('[Hardware] 震动失败: $e');
    }
  }
}

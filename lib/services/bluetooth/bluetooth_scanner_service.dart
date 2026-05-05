// 蓝牙扫描服务
//
// 扫描附近的蓝牙设备

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙扫描服务
class BluetoothScannerService extends ChangeNotifier {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isBluetoothOn = false;

  List<BluetoothDevice> get devices => _devices;
  bool get isScanning => _isScanning;
  bool get isBluetoothOn => _isBluetoothOn;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 检查蓝牙是否开启
      _isBluetoothOn = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
      debugPrint('[Bluetooth] 蓝牙状态: $_isBluetoothOn');

      // 监听蓝牙状态变化
      FlutterBluePlus.adapterState.listen((state) {
        _isBluetoothOn = state == BluetoothAdapterState.on;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[Bluetooth] 初始化失败: $e');
    }
  }

  /// 扫描设备
  Future<void> scanDevices({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isScanning) return;

    if (!_isBluetoothOn) {
      debugPrint('[Bluetooth] 蓝牙未开启');
      return;
    }

    try {
      _isScanning = true;
      _devices.clear();
      notifyListeners();

      debugPrint('[Bluetooth] 开始扫描...');

      // 开始扫描
      await FlutterBluePlus.startScan(timeout: timeout);

      // 监听扫描结果
      FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (!_devices.any((d) => d.remoteId == result.device.remoteId)) {
            _devices.add(result.device);
            notifyListeners();
          }
        }
      });

      // 等待扫描完成
      await Future.delayed(timeout);

      _isScanning = false;
      notifyListeners();

      debugPrint('[Bluetooth] 扫描完成，找到 ${_devices.length} 个设备');
    } catch (e) {
      debugPrint('[Bluetooth] 扫描失败: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  /// 获取设备列表信息
  String getDevicesInfo() {
    if (!_isBluetoothOn) {
      return '❌ 蓝牙未开启';
    }

    if (_isScanning) {
      return '🔍 正在扫描蓝牙设备...';
    }

    if (_devices.isEmpty) {
      return '🔍 未找到蓝牙设备';
    }

    final buffer = StringBuffer();
    buffer.writeln('📡 蓝牙设备扫描结果');
    buffer.writeln();
    buffer.writeln('找到 ${_devices.length} 个设备:');
    buffer.writeln();

    for (final device in _devices) {
      final name = device.platformName.isNotEmpty ? device.platformName : '未知设备';
      buffer.writeln('• $name (${device.remoteId})');
    }

    return buffer.toString();
  }

  /// 清空设备列表
  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}

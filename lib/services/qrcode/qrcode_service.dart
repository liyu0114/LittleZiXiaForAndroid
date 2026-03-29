// 二维码服务
//
// 生成和扫描二维码

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 二维码服务
class QRCodeService extends ChangeNotifier {
  MobileScannerController? _scannerController;
  String? _lastScanned;
  bool _isScanning = false;

  String? get lastScanned => _lastScanned;
  bool get isScanning => _isScanning;
  MobileScannerController? get scannerController => _scannerController;

  /// 生成二维码
  Future<void> generateQRCode(
    String data, {
    int size = 200,
    Color? foregroundColor,
    Color? backgroundColor,
  }) async {
    try {
      // TODO: 实现二维码生成
      debugPrint('[QRCode] 生成二维码: $data');
    } catch (e) {
      debugPrint('[QRCode] 生成失败: $e');
    }
  }

  /// 开始扫描
  void startScanning(Function(String) onDetected) {
    if (_isScanning) return;

    _isScanning = true;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    debugPrint('[QRCode] 开始扫描');
  }

  /// 停止扫描
  void stopScanning() {
    _scannerController?.dispose();
    _scannerController = null;
    _isScanning = false;
    debugPrint('[QRCode] 停止扫描');
  }

  /// 处理扫描结果
  void handleDetection(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        _lastScanned = barcode.rawValue;
        notifyListeners();
        debugPrint('[QRCode] 扫描到: $_lastScanned');
      }
    }
  }

  /// 获取扫描信息
  String getScanInfo() {
    if (!_isScanning) {
      return '⚠️ 未开始扫描';
    }

    if (_lastScanned != null) {
      return '''📷 二维码扫描结果

内容: $_lastScanned''';
    }

    return '🔍 正在扫描二维码...';
  }

  /// 清除结果
  void clearResult() {
    _lastScanned = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}

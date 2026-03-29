// NFC 读取服务
//
// 读取 NFC 标签内容

import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

/// NFC 读取服务
class NFCReaderService extends ChangeNotifier {
  NFCAvailability _availability = NFCAvailability.not_supported;
  NFCTag? _lastTag;
  bool _isReading = false;

  NFCAvailability get availability => _availability;
  NFCTag? get lastTag => _lastTag;
  bool get isReading => _isReading;
  bool get isAvailable => _availability == NFCAvailability.available;

  /// 初始化
  Future<void> initialize() async {
    try {
      _availability = await FlutterNfcKit.nfcAvailability;
      debugPrint('[NFC] 可用性: $_availability');
      notifyListeners();
    } catch (e) {
      debugPrint('[NFC] 初始化失败: $e');
    }
  }

  /// 读取标签
  Future<NFCTag?> readTag({Duration timeout = const Duration(seconds: 30)}) async {
    if (!isAvailable) {
      debugPrint('[NFC] NFC 不可用');
      return null;
    }

    try {
      _isReading = true;
      notifyListeners();

      debugPrint('[NFC] 开始读取标签...');

      // 轮询标签
      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosMultipleTagMessage: "检测到多个标签，请只保留一个",
        iosAlertMessage: "请将 NFC 标签靠近设备",
      );

      _lastTag = tag;
      notifyListeners();

      debugPrint('[NFC] 读取成功: ${tag.type}');
      return tag;
    } catch (e) {
      debugPrint('[NFC] 读取失败: $e');
      return null;
    } finally {
      _isReading = false;
      notifyListeners();
    }
  }

  /// 获取标签信息
  String getTagInfo() {
    if (!isAvailable) {
      return '❌ 设备不支持 NFC 或未开启';
    }

    if (_isReading) {
      return '🔍 正在读取 NFC 标签...';
    }

    if (_lastTag == null) {
      return '⚠️ 未读取到标签';
    }

    final buffer = StringBuffer();
    buffer.writeln('📱 NFC 标签信息');
    buffer.writeln();
    buffer.writeln('类型: ${_lastTag!.type}');
    buffer.writeln('ID: ${_lastTag!.id}');
    buffer.writeln('标准: ${_lastTag!.standard}');

    // Note: flutter_nfc_kit 3.6.2 的 API 可能不同
    // 简化输出，避免使用可能不存在的属性

    return buffer.toString();
  }

  /// 清除标签
  void clearTag() {
    _lastTag = null;
    notifyListeners();
  }
}

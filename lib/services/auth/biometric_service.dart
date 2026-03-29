// 生物识别服务
//
// 指纹/面部识别

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// 生物识别服务
class BiometricService extends ChangeNotifier {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isAuthenticated = false;
  String _status = '未检查';

  bool get canCheckBiometrics => _canCheckBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get isAuthenticated => _isAuthenticated;
  String get status => _status;

  /// 初始化
  Future<void> initialize() async {
    try {
      // 检查是否支持生物识别
      _canCheckBiometrics = await _auth.canCheckBiometrics;
      debugPrint('[Biometric] 支持生物识别: $_canCheckBiometrics');

      // 获取可用的生物识别类型
      _availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('[Biometric] 可用类型: $_availableBiometrics');

      if (_canCheckBiometrics) {
        _status = '已就绪';
      } else {
        _status = '不支持生物识别';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[Biometric] 初始化失败: $e');
      _status = '初始化失败: $e';
      notifyListeners();
    }
  }

  /// 认证
  Future<bool> authenticate({
    String localizedReason = '请验证身份',
    bool stickyAuth = false,
  }) async {
    if (!_canCheckBiometrics) {
      debugPrint('[Biometric] 不支持生物识别');
      _status = '不支持生物识别';
      notifyListeners();
      return false;
    }

    try {
      _status = '认证中...';
      notifyListeners();

      _isAuthenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,  // 只用生物识别，不允许 PIN
        ),
      );

      if (_isAuthenticated) {
        debugPrint('[Biometric] ✅ 认证成功');
        _status = '认证成功';
      } else {
        debugPrint('[Biometric] ❌ 认证失败');
        _status = '认证失败';
      }

      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      debugPrint('[Biometric] 认证错误: $e');
      _status = '错误: $e';
      notifyListeners();
      return false;
    }
  }

  /// 停止认证
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
      _status = '已取消';
      notifyListeners();
    } catch (e) {
      debugPrint('[Biometric] 停止失败: $e');
    }
  }

  /// 获取生物识别类型描述
  String getBiometricTypeDescription() {
    if (_availableBiometrics.isEmpty) {
      return '无可用生物识别';
    }

    final types = <String>[];
    for (final type in _availableBiometrics) {
      switch (type) {
        case BiometricType.fingerprint:
          types.add('指纹');
          break;
        case BiometricType.face:
          types.add('面部');
          break;
        case BiometricType.iris:
          types.add('虹膜');
          break;
        case BiometricType.weak:
          types.add('弱生物识别');
          break;
        default:
          types.add('其他');
      }
    }

    return types.join('、');
  }

  /// 检查是否支持指纹
  bool get hasFingerprint => _availableBiometrics.contains(BiometricType.fingerprint);

  /// 检查是否支持面部识别
  bool get hasFaceID => _availableBiometrics.contains(BiometricType.face);

  /// 检查是否支持虹膜
  bool get hasIris => _availableBiometrics.contains(BiometricType.iris);
}

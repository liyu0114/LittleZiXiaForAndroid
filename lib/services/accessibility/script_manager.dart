// 自动化脚本管理器
// 统一管理所有APP自动化脚本

import 'package:flutter/foundation.dart';
import 'accessibility_service.dart';
import 'alipay_script.dart';
import 'wechat_script.dart';
import 'taobao_script.dart';
import 'douyin_script.dart';

/// APP类型
enum AppType {
  alipay,
  wechat,
  taobao,
  douyin,
}

/// APP配置
class AppConfig {
  final AppType type;
  final String name;
  final String packageName;
  
  const AppConfig({
    required this.type,
    required this.name,
    required this.packageName,
  });
  
  static const Map<AppType, AppConfig> apps = {
    AppType.alipay: AppConfig(type: AppType.alipay, name: '支付宝', packageName: 'com.eg.android.AlipayGphone'),
    AppType.wechat: AppConfig(type: AppType.wechat, name: '微信', packageName: 'com.tencent.mm'),
    AppType.taobao: AppConfig(type: AppType.taobao, name: '淘宝', packageName: 'com.taobao.taobao'),
    AppType.douyin: AppConfig(type: AppType.douyin, name: '抖音', packageName: 'com.ss.android.ugc.aweme'),
  };
}

/// 脚本管理器
class ScriptManager {
  final AccessibilityService _access;
  
  AlipayScript? _alipay;
  WeChatScript? _wechat;
  TaoBaoScript? _taobao;
  DouyinScript? _douyin;
  
  ScriptManager(this._access) {
    _alipay = AlipayScript(_access);
    _wechat = WeChatScript(_access);
    _taobao = TaoBaoScript(_access);
    _douyin = DouyinScript(_access);
  }
  
  /// 获取所有支持的APP
  static List<AppConfig> getSupportedApps() {
    return AppConfig.apps.values.toList();
  }
  
  /// 执行通用操作
  Future<Map<String, dynamic>> execute(AppType app, String action, {Map<String, dynamic>? params}) async {
    debugPrint('[ScriptManager] 执行: ${AppConfig.apps[app]?.name} - $action');
    
    try {
      switch (app) {
        case AppType.alipay:
          return await _executeAlipay(action, params);
        case AppType.wechat:
          return await _executeWechat(action, params);
        case AppType.taobao:
          return await _executeTaoBao(action, params);
        case AppType.douyin:
          return await _executeDouyin(action, params);
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> _executeAlipay(String action, Map<String, dynamic>? params) async {
    switch (action) {
      case 'open':
        return {'success': await _alipay!.open()};
      case 'scan':
        return {'success': await _alipay!.runScanFlow()};
      case 'payCode':
        return {'success': await _alipay!.runPayCodeFlow()};
      case 'balance':
        final balance = await _alipay!.runQueryBalanceFlow();
        return {'success': balance != null, 'balance': balance};
      case 'transfer':
        final result = await _alipay!.transfer(
          params?['account'] ?? '',
          (params?['amount'] ?? 0).toDouble(),
        );
        return {'success': result};
      default:
        return {'success': false, 'error': '未知操作'};
    }
  }
  
  Future<Map<String, dynamic>> _executeWechat(String action, Map<String, dynamic>? params) async {
    switch (action) {
      case 'open':
        return {'success': await _wechat!.open()};
      case 'scan':
        return {'success': await _wechat!.clickScan()};
      case 'receive':
        return {'success': await _wechat!.clickReceive()};
      case 'balance':
        final balance = await _wechat!.queryBalance();
        return {'success': balance != null, 'balance': balance};
      default:
        return {'success': false, 'error': '未知操作'};
    }
  }
  
  Future<Map<String, dynamic>> _executeTaoBao(String action, Map<String, dynamic>? params) async {
    switch (action) {
      case 'open':
        return {'success': await _taobao!.open()};
      case 'search':
        return {'success': await _taobao!.search(params?['keyword'] ?? '')};
      case 'cart':
        return {'success': await _taobao!.clickCart()};
      case 'orders':
        final result = await _taobao!.queryOrders();
        return {'success': result != null, 'orders': result};
      default:
        return {'success': false, 'error': '未知操作'};
    }
  }
  
  Future<Map<String, dynamic>> _executeDouyin(String action, Map<String, dynamic>? params) async {
    switch (action) {
      case 'open':
        return {'success': await _douyin!.open()};
      case 'like':
        return {'success': await _douyin!.like()};
      case 'comment':
        return {'success': await _douyin!.comment()};
      case 'share':
        return {'success': await _douyin!.share()};
      case 'follow':
        return {'success': await _douyin!.clickFollow()};
      default:
        return {'success': false, 'error': '未知操作'};
    }
  }
}
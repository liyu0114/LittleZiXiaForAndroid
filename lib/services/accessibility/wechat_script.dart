// 微信自动化脚本
// 包含：打开微信、扫码、转账、查余额等

import 'package:flutter/foundation.dart';
import 'accessibility_service.dart';

/// 微信脚本
class WeChatScript {
  final AccessibilityService _accessibility;
  
  static const String _packageName = "com.tencent.mm";
  
  WeChatScript(this._accessibility);
  
  /// 打开微信
  Future<bool> open() async {
    try {
      debugPrint('[WeChatScript] 打开微信...');
      return await _accessibility.launchApp(_packageName);
    } catch (e) {
      debugPrint('[WeChatScript] 打开微信失败: $e');
      return false;
    }
  }
  
  /// 等待微信加载
  Future<bool> waitForLoad({int timeoutSec: 10}) async {
    for (int i = 0; i < timeoutSec; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final package = await _accessibility.getCurrentPackage();
      if (package == _packageName) {
        return true;
      }
    }
    return false;
  }
  
  /// 点击首页扫一扫
  Future<bool> clickScan() async {
    debugPrint('[WeChatScript] 点击扫一扫...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    // 微信首页右上角"+" -> "扫一扫"
    final plusNode = node.findText('+');
    if (plusNode != null) {
      await _accessibility.click(plusNode.id);
      await Future.delayed(Duration(milliseconds: 500));
      
      final scanNode = node.findText('扫一扫');
      if (scanNode != null) {
        return await _accessibility.click(scanNode.id);
      }
    }
    return false;
  }
  
  /// 点击收付款
  Future<bool> clickReceive() async {
    debugPrint('[WeChatScript] 点击收付款...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final receiveNode = node.findText('收付款');
    if (receiveNode != null) {
      return await _accessibility.click(receiveNode.id);
    }
    return false;
  }
  
  /// 点击转账
  Future<bool> clickTransfer() async {
    debugPrint('[WeChatScript] 点击转账...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final transferNode = node.findText('转账');
    if (transferNode != null) {
      return await _accessibility.click(transferNode.id);
    }
    return false;
  }
  
  /// 点击钱包
  Future<bool> clickWallet() async {
    debugPrint('[WeChatScript] 点击钱包...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final walletNode = node.findText('钱包');
    if (walletNode != null) {
      return await _accessibility.click(walletNode.id);
    }
    return false;
  }
  
  /// 点击我的
  Future<bool> clickMine() async {
    debugPrint('[WeChatScript] 点击我的...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final mineNode = node.findText('我');
    if (mineNode != null) {
      return await _accessibility.click(mineNode.id);
    }
    return false;
  }
  
  /// 查询余额流程
  Future<String?> queryBalance() async {
    debugPrint('[WeChatScript] 查询余额...');
    
    if (!await open()) return null;
    if (!await waitForLoad()) return null;
    
    // 进入钱包
    if (!await clickWallet()) return null;
    await Future.delayed(Duration(milliseconds: 500));
    
    // 查找余额
    final node = await _accessibility.getRootNode();
    if (node == null) return null;
    
    // 查找"余额"相关文本
    // TODO: 解析余额数值
    
    return '查询完成';
  }
}
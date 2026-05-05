// 支付宝自动化脚本
// 包含：打开支付宝、扫码、转账、查询余额等操作

import 'package:flutter/foundation.dart';
import 'accessibility_service.dart';

/// 支付宝脚本
class AlipayScript {
  final AccessibilityService _accessibility;
  
  static const String _packageName = "com.eg.android.AlipayGphone";
  
  AlipayScript(this._accessibility);
  
  /// 打开支付宝
  Future<bool> open() async {
    try {
      debugPrint('[AlipayScript] 打开支付宝...');
      return await _accessibility.launchApp(_packageName);
    } catch (e) {
      debugPrint('[AlipayScript] 打开支付宝失败: $e');
      return false;
    }
  }
  
  /// 等待支付宝加载完成
  Future<bool> waitForLoad({int timeoutSec: 10}) async {
    for (int i = 0; i < timeoutSec; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final package = await _accessibility.getCurrentPackage();
      if (package == _packageName) {
        final node = await _accessibility.getRootNode();
        if (node != null) {
          debugPrint('[AlipayScript] 支付宝已加载');
          return true;
        }
      }
    }
    debugPrint('[AlipayScript] 支付宝加载超时');
    return false;
  }
  
  /// 点击首页扫一扫
  Future<bool> clickScan() async {
    debugPrint('[AlipayScript] 点击扫一扫...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    // 查找"扫一扫"按钮
    final scanNode = node.findText('扫一扫');
    if (scanNode != null) {
      return await _accessibility.click(scanNode.id);
    }
    
    // 备用：点击右下角扫码入口（需要截图识别位置）
    // 这里返回false，需要后续优化
    debugPrint('[AlipayScript] 未找到扫一扫按钮');
    return false;
  }
  
  /// 点击首页付款码
  Future<bool> clickPayCode() async {
    debugPrint('[AlipayScript] 点击付款码...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final payNode = node.findText('付款码');
    if (payNode != null) {
      return await _accessibility.click(payNode.id);
    }
    
    debugPrint('[AlipayScript] 未找到付款码按钮');
    return false;
  }
  
  /// 点击首页转账
  Future<bool> clickTransfer() async {
    debugPrint('[AlipayScript] 点击转账...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final transferNode = node.findText('转账');
    if (transferNode != null) {
      return await _accessibility.click(transferNode.id);
    }
    
    debugPrint('[AlipayScript] 未找到转账按钮');
    return false;
  }
  
  /// 点击首页余额宝
  Future<bool> clickYeb() async {
    debugPrint('[AlipayScript] 点击余额宝...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final yebNode = node.findText('余额宝');
    if (yebNode != null) {
      return await _accessibility.click(yebNode.id);
    }
    
    debugPrint('[AlipayScript] 未找到余额宝按钮');
    return false;
  }
  
  /// 点击首页我的
  Future<bool> clickMine() async {
    debugPrint('[AlipayScript] 点击我的...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final mineNode = node.findText('我的');
    if (mineNode != null) {
      return await _accessibility.click(mineNode.id);
    }
    
    debugPrint('[AlipayScript] 未找到我的按钮');
    return false;
  }
  
  /// 进入转账页面，输入金额并转账
  Future<bool> transfer(String account, double amount) async {
    debugPrint('[AlipayScript] 转账: $account, $amount');
    
    // 1. 点击转账
    if (!await clickTransfer()) return false;
    await Future.delayed(const Duration(seconds: 1));
    
    // 2. 输入对方账号（这里需要先找到输入框）
    // TODO: 完善输入逻辑
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    // 3. 输入金额
    // TODO: 完善输入逻辑
    
    // 4. 确认转账
    // TODO: 完善确认逻辑
    
    return true;
  }
  
  /// 查询余额
  Future<double?> queryBalance() async {
    debugPrint('[AlipayScript] 查询余额...');
    
    // 1. 进入我的页面
    if (!await clickMine()) return null;
    await Future.delayed(const Duration(seconds: 1));
    
    // 2. 查找余额显示
    final node = await _accessibility.getRootNode();
    if (node == null) return null;
    
    // 查找"余额"相关文本
    final balanceNode = node.findText('余额');
    if (balanceNode == null) return null;
    
    // TODO: 解析余额数值
    // 需要从文本中提取数字
    
    return null;
  }
  
  /// 执行完整流程：打开支付宝→扫码
  Future<bool> runScanFlow() async {
    debugPrint('[AlipayScript] 执行扫一扫流程...');
    
    // 1. 打开支付宝
    if (!await open()) {
      debugPrint('[AlipayScript] 打开支付宝失败');
      return false;
    }
    
    // 2. 等待加载
    if (!await waitForLoad()) {
      debugPrint('[AlipayScript] 等待加载失败');
      return false;
    }
    
    // 3. 点击扫一扫
    return await clickScan();
  }
  
  /// 执行完整流程：打开支付宝→付款码
  Future<bool> runPayCodeFlow() async {
    debugPrint('[AlipayScript] 执行付款码流程...');
    
    if (!await open()) return false;
    if (!await waitForLoad()) return false;
    
    return await clickPayCode();
  }
  
  /// 执行完整流程：查询余额
  Future<double?> runQueryBalanceFlow() async {
    debugPrint('[AlipayScript] 执行查询余额流程...');
    
    if (!await open()) return null;
    if (!await waitForLoad()) return null;
    
    return await queryBalance();
  }
}
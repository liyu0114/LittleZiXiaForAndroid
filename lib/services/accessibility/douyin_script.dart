// 抖音自动化脚本
// 包含：打开抖音、视频操作等

import 'package:flutter/foundation.dart';
import 'accessibility_service.dart';

/// 抖音脚本
class DouyinScript {
  final AccessibilityService _accessibility;
  
  static const String _packageName = "com.ss.android.ugc.aweme";
  
  DouyinScript(this._accessibility);
  
  /// 打开抖音
  Future<bool> open() async {
    try {
      debugPrint('[DouyinScript] 打开抖音...');
      return await _accessibility.launchApp(_packageName);
    } catch (e) {
      debugPrint('[DouyinScript] 打开抖音失败: $e');
      return false;
    }
  }
  
  /// 等待加载
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
  
  /// 滑动切换视频
  Future<bool> swipeUp() async {
    debugPrint('[DouyinScript] 滑动切换...');
    // 上滑
    return await _accessibility.clickAt(540, 1800); // 临时位置
  }
  
  /// 点赞
  Future<bool> like() async {
    debugPrint('[DouyinScript] 点赞...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    // 点赞按钮位置（临时）
    return await _accessibility.clickAt(100, 1200);
  }
  
  /// 评论
  Future<bool> comment() async {
    debugPrint('[DouyinScript] 评论...');
    // TODO: 点击评论入口
    return await _accessibility.clickAt(990, 1200);
  }
  
  /// 分享
  Future<bool> share() async {
    debugPrint('[DouyinScript] 分享...');
    return await _accessibility.clickAt(900, 1200);
  }
  
  /// 点击关注
  Future<bool> clickFollow() async {
    debugPrint('[DouyinScript] 点击关注...');
    final node = await _accessibility.getRootNode();
    if (node == null) return false;
    
    final followNode = node.findText('关注');
    if (followNode != null) {
      return await _accessibility.click(followNode.id);
    }
    return false;
  }
  
  /// 搜索用户
  Future<bool> search(String keyword) async {
    debugPrint('[DouyinScript] 搜索: $keyword');
    
    // 先点击搜索图标
    return await _accessibility.clickAt(1000, 100);
  }
}
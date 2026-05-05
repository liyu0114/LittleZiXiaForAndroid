// HTTP代理服务
//
// 代理HTTP请求

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 代理规则
class ProxyRule {
  final String pattern;
  final String replacement;
  final bool enabled;
  
  ProxyRule({
    required this.pattern,
    required this.replacement,
    this.enabled = true,
  });
}

/// HTTP代理
class HttpProxy extends ChangeNotifier {
  final List<ProxyRule> _rules = [];
  bool _isEnabled = false;
  
  bool get isEnabled => _isEnabled;
  
  /// 添加规则
  void addRule(ProxyRule rule) {
    _rules.add(rule);
    notifyListeners();
  }
  
  /// 移除规则
  void removeRule(String pattern) {
    _rules.removeWhere((r) => r.pattern == pattern);
    notifyListeners();
  }
  
  /// 启用/禁用
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }
  
  /// 拦截请求
  String? intercept(String url) {
    if (!_isEnabled) return null;
    
    for (final rule in _rules) {
      if (rule.enabled && url.contains(rule.pattern)) {
        return url.replaceFirst(rule.pattern, rule.replacement);
      }
    }
    return null;
  }
}
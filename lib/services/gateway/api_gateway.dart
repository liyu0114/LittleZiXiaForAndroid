// API网关
//
// 请求路由+限流+认证

import 'dart:async';
import 'package:flutter/foundation.dart';

/// API路由
class ApiRoute {
  final String path;
  final String handler;
  final List<String> methods;
  final bool authRequired;
  
  ApiRoute({
    required this.path,
    required this.handler,
    required this.methods,
    this.authRequired = true,
  });
}

/// API网关
class ApiGateway extends ChangeNotifier {
  final List<ApiRoute> _routes = [];
  final Map<String, int> _rateLimit = {};
  bool _isEnabled = false;
  
  /// 添加路由
  void addRoute(ApiRoute route) {
    _routes.add(route);
    notifyListeners();
  }
  
  /// 路由请求
  Future<String?> route(String path, String method) async {
    final route = _routes.firstWhere(
      (r) => r.path == path && r.methods.contains(method),
      orElse: () => throw Exception('路由不存在'),
    );
    return route.handler;
  }
  
  /// 限流检查
  bool checkRateLimit(String clientId, {int limit = 100, int windowSeconds = 60}) {
    final now = DateTime.now();
    _rateLimit[clientId] = (_rateLimit[clientId] ?? 0) + 1;
    
    if (_rateLimit[clientId]! > limit) {
      debugPrint('[ApiGateway] 限流: $clientId');
      return false;
    }
    return true;
  }
}
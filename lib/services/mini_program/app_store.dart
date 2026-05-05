// 小程序应用市场
//
// 发布、发现、安装小程序

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 应用市场
class AppStore extends ChangeNotifier {
  final List<StoreApp> _apps = [];
  
  List<StoreApp> get apps => List.unmodifiable(_apps);
  
  /// 发现应用（浏览）
  Future<List<StoreApp>> browse({int limit = 20}) async {
    // TODO: 从服务器获取
    return _apps.take(limit).toList();
  }
  
  /// 搜索应用
  Future<List<StoreApp>> search(String query) async {
    final results = _apps.where((app) {
      return app.name.toLowerCase().contains(query.toLowerCase()) ||
             app.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
    
    return results;
  }
  
  /// 发布应用到市场
  Future<String> publish(MiniProgram program) async {
    final storeApp = StoreApp(
      id: program.id,
      name: program.name,
      description: program.description ?? '',
      author: 'user',
      version: '1.0.0',
      createdAt: DateTime.now(),
      downloads: 0,
      rating: 5.0,
    );
    
    _apps.add(storeApp);
    notifyListeners();
    
    return storeApp.id;
  }
  
  /// 安装应用
  Future<void> install(String appId) async {
    // TODO: 下载并安装
    final app = _apps.firstWhere((a) => a.id == appId);
    app.downloads++;
    notifyListeners();
  }
  
  /// 评分
  Future<void> rate(String appId, int stars) async {
    final app = _apps.firstWhere((a) => a.id == appId);
    // 简单评分：更新平均
    final newRating = (app.rating * app.downloads + stars) / (app.downloads + 1);
    app.rating = newRating;
    notifyListeners();
  }
}

/// 市场应用信息
class StoreApp {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final DateTime createdAt;
  int downloads;
  double rating;
  
  StoreApp({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.createdAt,
    this.downloads = 0,
    this.rating = 5.0,
  });
}
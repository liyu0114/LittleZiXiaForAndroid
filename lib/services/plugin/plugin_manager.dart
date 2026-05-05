// 插件管理器
//
// 插件加载和管理

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 插件信息
class Plugin {
  final String id;
  final String name;
  final String version;
  final bool isEnabled;
  
  Plugin({
    required this.id,
    required this.name,
    required this.version,
    this.isEnabled = true,
  });
}

/// 插件管理器
class PluginManager extends ChangeNotifier {
  final List<Plugin> _plugins = [];
  
  List<Plugin> get plugins => List.unmodifiable(_plugins);
  List<Plugin> get enabled => _plugins.where((p) => p.isEnabled).toList();
  
  /// 加载插件
  Future<void> loadPlugin(String id, String name, String version) async {
    _plugins.add(Plugin(
      id: id,
      name: name,
      version: version,
    ));
    notifyListeners();
  }
  
  /// 卸载插件
  Future<void> unloadPlugin(String id) async {
    _plugins.removeWhere((p) => p.id == id);
    notifyListeners();
  }
  
  /// 启用插件
  void enablePlugin(String id) {
    final index = _plugins.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plugins[index] = Plugin(
        id: _plugins[index].id,
        name: _plugins[index].name,
        version: _plugins[index].version,
        isEnabled: true,
      );
      notifyListeners();
    }
  }
  
  /// 禁用插件
  void disablePlugin(String id) {
    final index = _plugins.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plugins[index] = Plugin(
        id: _plugins[index].id,
        name: _plugins[index].name,
        version: _plugins[index].version,
        isEnabled: false,
      );
      notifyListeners();
    }
  }
}
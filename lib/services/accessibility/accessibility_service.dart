// Android 无障碍服务接口
//
// 通过 Platform Channel 调用 Android 原生 AccessibilityService

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 无障碍节点信息
class AccessibilityNode {
  final String id;
  final String? text;
  final String? contentDescription;
  final String className;
  final Rect bounds;
  final bool isClickable;
  final bool isScrollable;
  final bool isEditable;
  final bool isChecked;
  final bool isEnabled;
  final List<AccessibilityNode> children;

  AccessibilityNode({
    required this.id,
    this.text,
    this.contentDescription,
    required this.className,
    required this.bounds,
    this.isClickable = false,
    this.isScrollable = false,
    this.isEditable = false,
    this.isChecked = false,
    this.isEnabled = true,
    this.children = const [],
  });

  factory AccessibilityNode.fromMap(Map<String, dynamic> map) {
    return AccessibilityNode(
      id: map['id'] ?? '',
      text: map['text'],
      contentDescription: map['contentDescription'],
      className: map['className'] ?? '',
      bounds: Rect.fromLTWH(
        (map['bounds']['left'] ?? 0).toDouble(),
        (map['bounds']['top'] ?? 0).toDouble(),
        (map['bounds']['width'] ?? 0).toDouble(),
        (map['bounds']['height'] ?? 0).toDouble(),
      ),
      isClickable: map['isClickable'] ?? false,
      isScrollable: map['isScrollable'] ?? false,
      isEditable: map['isEditable'] ?? false,
      isChecked: map['isChecked'] ?? false,
      isEnabled: map['isEnabled'] ?? true,
      children: (map['children'] as List?)
          ?.map((c) => AccessibilityNode.fromMap(c))
          .toList() ?? [],
    );
  }

  /// 查找包含指定文本的节点
  AccessibilityNode? findText(String text) {
    if (this.text?.contains(text) == true ||
        contentDescription?.contains(text) == true) {
      return this;
    }
    for (final child in children) {
      final found = child.findText(text);
      if (found != null) return found;
    }
    return null;
  }

  /// 查找可点击的节点
  List<AccessibilityNode> findClickable() {
    final result = <AccessibilityNode>[];
    if (isClickable && isEnabled) {
      result.add(this);
    }
    for (final child in children) {
      result.addAll(child.findClickable());
    }
    return result;
  }
}

/// 无障碍服务
class AccessibilityService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.littlezixia/accessibility');
  
  bool _isEnabled = false;
  bool _isConnected = false;
  AccessibilityNode? _rootNode;

  bool get isEnabled => _isEnabled;
  bool get isConnected => _isConnected;
  AccessibilityNode? get rootNode => _rootNode;

  /// 检查无障碍服务是否已启用
  Future<bool> checkEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkEnabled');
      _isEnabled = result ?? false;
      notifyListeners();
      return _isEnabled;
    } catch (e) {
      debugPrint('[AccessibilityService] 检查失败: $e');
      return false;
    }
  }

  /// 打开无障碍设置页面
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      debugPrint('[AccessibilityService] 打开设置失败: $e');
    }
  }

  /// 获取当前屏幕节点树
  Future<AccessibilityNode?> getRootNode() async {
    try {
      final result = await _channel.invokeMethod<Map>('getRootNode');
      if (result != null) {
        _rootNode = AccessibilityNode.fromMap(result);
        notifyListeners();
        return _rootNode;
      }
    } catch (e) {
      debugPrint('[AccessibilityService] 获取节点失败: $e');
    }
    return null;
  }

  /// 点击指定节点
  Future<bool> click(String nodeId) async {
    try {
      final result = await _channel.invokeMethod<bool>('click', {'nodeId': nodeId});
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 点击失败: $e');
      return false;
    }
  }

  /// 点击坐标
  Future<bool> clickAt(double x, double y) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickAt', {'x': x, 'y': y});
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 点击坐标失败: $e');
      return false;
    }
  }

  /// 输入文本
  Future<bool> inputText(String nodeId, String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('inputText', {
        'nodeId': nodeId,
        'text': text,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 输入文本失败: $e');
      return false;
    }
  }

  /// 滚动
  Future<bool> scroll(String nodeId, String direction) async {
    try {
      final result = await _channel.invokeMethod<bool>('scroll', {
        'nodeId': nodeId,
        'direction': direction, // 'up', 'down', 'left', 'right'
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 滚动失败: $e');
      return false;
    }
  }

  /// 返回
  Future<bool> back() async {
    try {
      final result = await _channel.invokeMethod<bool>('back');
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 返回失败: $e');
      return false;
    }
  }

  /// 回到主页
  Future<bool> home() async {
    try {
      final result = await _channel.invokeMethod<bool>('home');
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 回到主页失败: $e');
      return false;
    }
  }

  /// 打开最近任务
  Future<bool> recents() async {
    try {
      final result = await _channel.invokeMethod<bool>('recents');
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 打开最近任务失败: $e');
      return false;
    }
  }

  /// 启动应用
  Future<bool> launchApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[AccessibilityService] 启动应用失败: $e');
      return false;
    }
  }

  /// 等待指定文本出现
  Future<AccessibilityNode?> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      final node = await getRootNode();
      if (node != null) {
        final found = node.findText(text);
        if (found != null) return found;
      }
      await Future.delayed(interval);
    }
    
    return null;
  }

  /// 等待指定包名出现
  Future<bool> waitForPackage(
    String packageName, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      try {
        final currentPackage = await _channel.invokeMethod<String>('getCurrentPackage');
        if (currentPackage == packageName) return true;
      } catch (e) {
        // 忽略
      }
      await Future.delayed(interval);
    }
    
    return false;
  }
}

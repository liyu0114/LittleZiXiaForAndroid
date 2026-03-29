/// 铁律系统
/// 
/// 永不遗忘的核心规则，每次对话都强制加载到 System Prompt

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 铁律分类
enum IronLawCategory {
  behavior,    // 行为铁律
  identity,    // 身份铁律
  work,        // 工作铁律
  preference,  // 偏好铁律
  taboo,       // 禁忌铁律
}

/// 铁律分类扩展
extension IronLawCategoryExtension on IronLawCategory {
  String get displayName {
    switch (this) {
      case IronLawCategory.behavior:
        return '行为铁律';
      case IronLawCategory.identity:
        return '身份铁律';
      case IronLawCategory.work:
        return '工作铁律';
      case IronLawCategory.preference:
        return '偏好铁律';
      case IronLawCategory.taboo:
        return '禁忌铁律';
    }
  }
  
  String get description {
    switch (this) {
      case IronLawCategory.behavior:
        return '关于行为方式的核心规则';
      case IronLawCategory.identity:
        return '关于身份和角色的核心定义';
      case IronLawCategory.work:
        return '关于工作流程和要求的规定';
      case IronLawCategory.preference:
        return '关于用户偏好的记录';
      case IronLawCategory.taboo:
        return '绝对禁止的行为';
    }
  }
}

/// 铁律条目
class IronLaw {
  final String id;
  final IronLawCategory category;
  final String content;
  final int priority;          // 1-10，10最高
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  
  IronLaw({
    required this.id,
    required this.category,
    required this.content,
    this.priority = 5,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });
  
  factory IronLaw.fromJson(Map<String, dynamic> json) {
    return IronLaw(
      id: json['id'] as String,
      category: IronLawCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => IronLawCategory.behavior,
      ),
      content: json['content'] as String,
      priority: json['priority'] as int? ?? 5,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'content': content,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }
  
  IronLaw copyWith({
    String? id,
    IronLawCategory? category,
    String? content,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return IronLaw(
      id: id ?? this.id,
      category: category ?? this.category,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 铁律系统
class IronLawSystem extends ChangeNotifier {
  static const String _storageKey = 'iron_laws';
  
  final Map<String, IronLaw> _laws = {};
  bool _isLoaded = false;
  
  // Getters
  List<IronLaw> get allLaws => _laws.values.toList();
  List<IronLaw> get activeLaws => _laws.values.where((l) => l.isActive).toList();
  bool get isLoaded => _isLoaded;
  int get count => _laws.length;
  int get activeCount => activeLaws.length;
  
  /// 按分类获取
  List<IronLaw> getByCategory(IronLawCategory category) {
    return _laws.values.where((l) => l.category == category && l.isActive).toList();
  }
  
  /// 初始化 - 加载铁律
  Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        _laws.clear();
        for (final item in list) {
          final law = IronLaw.fromJson(item as Map<String, dynamic>);
          _laws[law.id] = law;
        }
      }
      
      // 如果没有铁律，添加默认铁律
      if (_laws.isEmpty) {
        await _addDefaultLaws();
      }
      
      _isLoaded = true;
      debugPrint('[IronLaw] 加载了 ${_laws.length} 条铁律');
      notifyListeners();
    } catch (e) {
      debugPrint('[IronLaw] 加载失败: $e');
    }
  }
  
  /// 添加默认铁律
  Future<void> _addDefaultLaws() async {
    final now = DateTime.now();
    
    final defaultLaws = [
      IronLaw(
        id: 'iron_default_1',
        category: IronLawCategory.behavior,
        content: '所有工作文件和项目都放在 D 盘，避免占用 C 盘空间',
        priority: 10,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
      IronLaw(
        id: 'iron_default_2',
        category: IronLawCategory.work,
        content: '超过半小时的工作，必须报告进展，不中断工作但要告知用户状态',
        priority: 9,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
      IronLaw(
        id: 'iron_default_3',
        category: IronLawCategory.preference,
        content: '喜欢简洁高效的沟通方式',
        priority: 7,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      ),
    ];
    
    for (final law in defaultLaws) {
      _laws[law.id] = law;
    }
    
    await save();
    debugPrint('[IronLaw] 添加了 ${defaultLaws.length} 条默认铁律');
  }
  
  /// 保存铁律
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _laws.values.map((l) => l.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      debugPrint('[IronLaw] 保存了 ${_laws.length} 条铁律');
    } catch (e) {
      debugPrint('[IronLaw] 保存失败: $e');
    }
  }
  
  /// 添加铁律
  Future<void> addLaw(IronLaw law) async {
    _laws[law.id] = law;
    await save();
    notifyListeners();
    debugPrint('[IronLaw] 添加铁律: ${law.content}');
  }
  
  /// 更新铁律
  Future<void> updateLaw(IronLaw law) async {
    _laws[law.id] = law.copyWith(updatedAt: DateTime.now());
    await save();
    notifyListeners();
    debugPrint('[IronLaw] 更新铁律: ${law.id}');
  }
  
  /// 删除铁律
  Future<void> deleteLaw(String id) async {
    _laws.remove(id);
    await save();
    notifyListeners();
    debugPrint('[IronLaw] 删除铁律: $id');
  }
  
  /// 启用/禁用铁律
  Future<void> toggleLaw(String id) async {
    final law = _laws[id];
    if (law != null) {
      _laws[id] = law.copyWith(
        isActive: !law.isActive,
        updatedAt: DateTime.now(),
      );
      await save();
      notifyListeners();
      debugPrint('[IronLaw] 切换铁律状态: $id -> ${!law.isActive}');
    }
  }
  
  /// 构建 System Prompt 中的铁律部分
  String buildIronLawPrompt() {
    if (activeLaws.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('## 铁律（必须遵守，永不遗忘）');
    buffer.writeln();
    
    // 按分类组织
    for (final category in IronLawCategory.values) {
      final laws = getByCategory(category);
      if (laws.isEmpty) continue;
      
      buffer.writeln('### ${category.displayName}');
      buffer.writeln();
      
      // 按优先级排序
      laws.sort((a, b) => b.priority.compareTo(a.priority));
      
      for (final law in laws) {
        buffer.writeln('- ${law.content}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('**注意：以上铁律是用户的核心要求，必须严格遵守，永不遗忘。**');
    buffer.writeln();
    
    return buffer.toString();
  }
  
  /// 注入铁律到 System Prompt
  String injectToSystemPrompt(String originalPrompt) {
    final ironLawPrompt = buildIronLawPrompt();
    if (ironLawPrompt.isEmpty) return originalPrompt;
    
    // 在 System Prompt 的开头注入铁律
    return ironLawPrompt + '\n' + originalPrompt;
  }
  
  /// 获取统计信息
  Map<String, dynamic> get statistics {
    final stats = <String, int>{};
    for (final category in IronLawCategory.values) {
      stats[category.name] = getByCategory(category).length;
    }
    return {
      'total': count,
      'active': activeCount,
      'byCategory': stats,
    };
  }
  
  /// 清空所有铁律
  Future<void> clear() async {
    _laws.clear();
    await save();
    notifyListeners();
    debugPrint('[IronLaw] 清空所有铁律');
  }
}

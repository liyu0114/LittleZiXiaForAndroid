/// Skill 生命周期管理
/// 
/// 管理技能的完整生命周期：
/// 待测试 → 待安装 → 已安装 → 禁用/卸载

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'skill_system.dart';

/// Skill 状态枚举
enum SkillStatus {
  pendingTest,    // 待测试（从 ClawHub 同步或对话生成）
  editing,             // 编辑中
  readyToInstall,  // 待安装（测试通过）
  installed,              // 已安装（正式启用）
  disabled,               // 已禁用（保留但不运行）
}

/// Skill 状态扩展方法
extension SkillStatusExtension on SkillStatus {
  String get displayName {
    switch (this) {
      case SkillStatus.pendingTest:
        return '待测试';
      case SkillStatus.editing:
        return '编辑中';
      case SkillStatus.readyToInstall:
        return '待安装';
      case SkillStatus.installed:
        return '已安装';
      case SkillStatus.disabled:
        return '已禁用';
    }
  }

  String get storagePath {
    switch (this) {
      case SkillStatus.pendingTest:
        return 'skills/pending/';
      case SkillStatus.editing:
        return 'skills/editing/';
      case SkillStatus.readyToInstall:
        return 'skills/ready/';
      case SkillStatus.installed:
        return 'skills/installed/';
      case SkillStatus.disabled:
        return 'skills/disabled/';
    }
  }
}

/// Skill 生命周期项
class SkillLifecycleItem {
  final String skillId;
  final String skillName;
  final SkillStatus status;
  final String? source;           // 'clawhub' | 'conversation' | 'local'
  final String? content;           // SKILL.md 内容
  final DateTime addedAt;
  final DateTime? testedAt;
  final String? testResult;        // 'success' | 'failed' | null
  final DateTime? installedAt;
  final List<String> tags;
  final String? description;

  SkillLifecycleItem({
    required this.skillId,
    required this.skillName,
    required this.status,
    this.source,
    this.content,
    required this.addedAt,
    this.testedAt,
    this.testResult,
    this.installedAt,
    this.tags = const [],
    this.description,
  });

  factory SkillLifecycleItem.fromJson(Map<String, dynamic> json) {
    return SkillLifecycleItem(
      skillId: json['skillId'] as String,
      skillName: json['skillName'] as String,
      status: SkillStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SkillStatus.pendingTest,
      ),
      source: json['source'] as String?,
      content: json['content'] as String?,
      addedAt: DateTime.parse(json['addedAt'] as String),
      testedAt: json['testedAt'] != null 
          ? DateTime.parse(json['testedAt'] as String) 
          : null,
      testResult: json['testResult'] as String?,
      installedAt: json['installedAt'] != null 
          ? DateTime.parse(json['installedAt'] as String) 
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skillId': skillId,
      'skillName': skillName,
      'status': status.name,
      'source': source,
      'content': content,
      'addedAt': addedAt.toIso8601String(),
      'testedAt': testedAt?.toIso8601String(),
      'testResult': testResult,
      'installedAt': installedAt?.toIso8601String(),
      'tags': tags,
      'description': description,
    };
  }

  SkillLifecycleItem copyWith({
    String? skillId,
    String? skillName,
    SkillStatus? status,
    String? source,
    String? content,
    DateTime? addedAt,
    DateTime? testedAt,
    String? testResult,
    DateTime? installedAt,
    List<String>? tags,
    String? description,
  }) {
    return SkillLifecycleItem(
      skillId: skillId ?? this.skillId,
      skillName: skillName ?? this.skillName,
      status: status ?? this.status,
      source: source ?? this.source,
      content: content ?? this.content,
      addedAt: addedAt ?? this.addedAt,
      testedAt: testedAt ?? this.testedAt,
      testResult: testResult ?? this.testResult,
      installedAt: installedAt ?? this.installedAt,
      tags: tags ?? this.tags,
      description: description ?? this.description,
    );
  }
}

/// Skill 生命周期管理器
class SkillLifecycleManager extends ChangeNotifier {
  static const String _storageKey = 'skill_lifecycle_items';
  
  final Map<String, SkillLifecycleItem> _items = {};
  final SkillRegistry _registry;
  
  SkillLifecycleManager(this._registry);

  /// 获取所有技能
  List<SkillLifecycleItem> get allItems => _items.values.toList();
  
  /// 按状态获取技能
  List<SkillLifecycleItem> getByStatus(SkillStatus status) {
    return _items.values.where((item) => item.status == status).toList();
  }
  
  /// 获取待测试技能
  List<SkillLifecycleItem> get pendingTest => getByStatus(SkillStatus.pendingTest);
  
  /// 获取待安装技能
  List<SkillLifecycleItem> get readyToInstall => getByStatus(SkillStatus.readyToInstall);
  
  /// 获取已安装技能
  List<SkillLifecycleItem> get installed => getByStatus(SkillStatus.installed);
  
  /// 获取已禁用技能
  List<SkillLifecycleItem> get disabled => getByStatus(SkillStatus.disabled);

  /// 初始化 - 从存储加载
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        for (final json in jsonList) {
          final item = SkillLifecycleItem.fromJson(json as Map<String, dynamic>);
          _items[item.skillId] = item;
        }
      }
      
      debugPrint('[SkillLifecycle] 加载了 ${_items.length} 个技能');
      notifyListeners();
    } catch (e) {
      debugPrint('[SkillLifecycle] 加载失败: $e');
    }
  }

  /// 保存到存储
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.values.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('[SkillLifecycle] 保存失败: $e');
    }
  }

  /// 添加到待测试列表
  Future<void> addToPendingTest(Skill skill, {String? source}) async {
    final item = SkillLifecycleItem(
      skillId: skill.id,
      skillName: skill.metadata.name,
      status: SkillStatus.pendingTest,
      source: source ?? 'local',
      content: skill.body,
      addedAt: DateTime.now(),
      tags: skill.metadata.openclaw?['tags']?.cast<String>() ?? [],
      description: skill.metadata.description,
    );
    
    _items[skill.id] = item;
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 添加到待测试: ${skill.id}');
  }

  /// 标记测试通过
  Future<void> markTestPassed(String skillId) async {
    final item = _items[skillId];
    if (item == null) return;
    
    _items[skillId] = item.copyWith(
      status: SkillStatus.readyToInstall,
      testedAt: DateTime.now(),
      testResult: 'success',
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 测试通过: $skillId');
  }

  /// 标记测试失败
  Future<void> markTestFailed(String skillId, {String? reason}) async {
    final item = _items[skillId];
    if (item == null) return;
    
    _items[skillId] = item.copyWith(
      status: SkillStatus.editing,
      testedAt: DateTime.now(),
      testResult: 'failed',
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 测试失败: $skillId (${reason ?? '无原因'})');
  }

  /// 安装技能
  Future<bool> installSkill(String skillId) async {
    final item = _items[skillId];
    if (item == null || item.status != SkillStatus.readyToInstall) {
      return false;
    }
    
    // 创建 Skill 对象并注册
    if (item.content != null) {
      final skill = Skill(
        id: skillId,
        metadata: SkillMetadata(
          name: item.skillName,
          description: item.description ?? '',
        ),
        body: item.content!,
      );
      
      _registry.register(skill);
    }
    
    _items[skillId] = item.copyWith(
      status: SkillStatus.installed,
      installedAt: DateTime.now(),
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 安装成功: $skillId');
    return true;
  }

  /// 禁用技能
  Future<void> disableSkill(String skillId) async {
    final item = _items[skillId];
    if (item == null || item.status != SkillStatus.installed) return;
    
    _registry.unregister(skillId);
    
    _items[skillId] = item.copyWith(
      status: SkillStatus.disabled,
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 已禁用: $skillId');
  }

  /// 启用技能
  Future<void> enableSkill(String skillId) async {
    final item = _items[skillId];
    if (item == null || item.status != SkillStatus.disabled) return;
    
    // 重新注册
    if (item.content != null) {
      final skill = Skill(
        id: skillId,
        metadata: SkillMetadata(
          name: item.skillName,
          description: item.description ?? '',
        ),
        body: item.content!,
      );
      
      _registry.register(skill);
    }
    
    _items[skillId] = item.copyWith(
      status: SkillStatus.installed,
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 已启用: $skillId');
  }

  /// 卸载技能
  Future<void> uninstallSkill(String skillId) async {
    final item = _items[skillId];
    if (item == null) return;
    
    _registry.unregister(skillId);
    _items.remove(skillId);
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 已卸载: $skillId');
  }

  /// 更新技能内容
  Future<void> updateSkillContent(String skillId, String content) async {
    final item = _items[skillId];
    if (item == null) return;
    
    _items[skillId] = item.copyWith(
      content: content,
      status: SkillStatus.editing,
    );
    
    await _save();
    notifyListeners();
    
    debugPrint('[SkillLifecycle] 内容已更新: $skillId');
  }

  /// 从对话生成 Skill
  Future<SkillLifecycleItem?> generateFromConversation(
    String conversationContent,
    String skillName,
    LLMProvider llmProvider,
  ) async {
    try {
      final prompt = '''
你是一个资深的程序员。帮助用户把特定对话转换成可复用的技能。

用户选择的对话：
$conversationContent

请根据以上对话生成一个 SKILL.md 文件，要求：
1. 提取核心功能
2. 定义清晰的参数（使用 {参数名} 格式）
3. 包含使用示例
4. 适合移动端使用

请直接输出 SKILL.md 的内容，不要包含其他说明。
''';

      final skillContent = await llmProvider.chat(prompt);
      
      final skillId = skillName.toLowerCase().replaceAll(' ', '_');
      
      final item = SkillLifecycleItem(
        skillId: skillId,
        skillName: skillName,
        status: SkillStatus.pendingTest,
        source: 'conversation',
        content: skillContent,
        addedAt: DateTime.now(),
        description: '从对话生成的技能',
      );
      
      _items[skillId] = item;
      await _save();
      notifyListeners();
      
      debugPrint('[SkillLifecycle] 从对话生成技能: $skillId');
      return item;
    } catch (e) {
      debugPrint('[SkillLifecycle] 生成技能失败: $e');
      return null;
    }
  }

  /// 获取技能统计
  Map<String, int> get statistics {
    return {
      'pendingTest': pendingTest.length,
      'readyToInstall': readyToInstall.length,
      'installed': installed.length,
      'disabled': disabled.length,
      'total': _items.length,
    };
  }
}

/// LLM Provider 接口（简化版）
abstract class LLMProvider {
  Future<String> chat(String message);
}

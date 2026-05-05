// 技能版本管理服务
//
// 跟踪技能的版本历史和更新

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'skill_system.dart';

/// 技能版本信息
class SkillVersion {
  final String version;
  final String? changelog;
  final DateTime createdAt;
  final String bodyHash;
  final String? body; // 可选，存储完整内容

  SkillVersion({
    required this.version,
    this.changelog,
    required this.createdAt,
    required this.bodyHash,
    this.body,
  });

  factory SkillVersion.fromJson(Map<String, dynamic> json) {
    return SkillVersion(
      version: json['version'] ?? '1.0.0',
      changelog: json['changelog'],
      createdAt: DateTime.parse(json['createdAt']),
      bodyHash: json['bodyHash'] ?? '',
      body: json['body'],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'changelog': changelog,
    'createdAt': createdAt.toIso8601String(),
    'bodyHash': bodyHash,
    if (body != null) 'body': body,
  };
}

/// 技能版本历史
class SkillVersionHistory {
  final String skillId;
  final List<SkillVersion> versions;
  final String currentVersion;

  SkillVersionHistory({
    required this.skillId,
    required this.versions,
    required this.currentVersion,
  });

  factory SkillVersionHistory.fromJson(Map<String, dynamic> json) {
    return SkillVersionHistory(
      skillId: json['skillId'] ?? '',
      versions: (json['versions'] as List?)
          ?.map((v) => SkillVersion.fromJson(v))
          .toList() ?? [],
      currentVersion: json['currentVersion'] ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'skillId': skillId,
    'versions': versions.map((v) => v.toJson()).toList(),
    'currentVersion': currentVersion,
  };
}

/// 技能版本管理器
class SkillVersionManager extends ChangeNotifier {
  static final SkillVersionManager _instance = SkillVersionManager._internal();
  factory SkillVersionManager() => _instance;
  SkillVersionManager._internal();

  static const String _storageKey = 'skill_versions_v1';
  
  final Map<String, SkillVersionHistory> _histories = {};
  
  /// 获取技能的版本历史
  SkillVersionHistory? getHistory(String skillId) => _histories[skillId];
  
  /// 获取当前版本
  String getCurrentVersion(String skillId) {
    return _histories[skillId]?.currentVersion ?? '1.0.0';
  }

  /// 初始化
  Future<void> initialize() async {
    await _loadFromStorage();
  }

  /// 从存储加载
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final Map<String, dynamic> data = json.decode(jsonStr);
        
        data.forEach((skillId, historyJson) {
          _histories[skillId] = SkillVersionHistory.fromJson(
            historyJson as Map<String, dynamic>,
          );
        });
        
        debugPrint('[SkillVersionManager] 加载了 ${_histories.length} 个版本历史');
      }
    } catch (e) {
      debugPrint('[SkillVersionManager] 加载失败: $e');
    }
  }

  /// 保存到存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final data = <String, dynamic>{};
      _histories.forEach((skillId, history) {
        data[skillId] = history.toJson();
      });
      
      await prefs.setString(_storageKey, json.encode(data));
    } catch (e) {
      debugPrint('[SkillVersionManager] 保存失败: $e');
    }
  }

  /// 生成内容哈希
  String _generateHash(String content) {
    // 简单的哈希算法
    var hash = 0;
    for (var i = 0; i < content.length; i++) {
      hash = ((hash << 5) - hash) + content.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.toRadixString(16);
  }

  /// 比较版本号
  int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      
      if (p1 != p2) return p1 - p2;
    }
    
    return 0;
  }

  /// 检查是否有更新
  bool hasUpdate(String skillId, String newVersion) {
    final history = _histories[skillId];
    if (history == null) return true;
    
    return compareVersions(newVersion, history.currentVersion) > 0;
  }

  /// 注册新版本
  Future<bool> registerVersion(
    Skill skill, {
    String version = '1.0.0',
    String? changelog,
  }) async {
    try {
      final skillId = skill.id;
      final bodyHash = _generateHash(skill.body);
      
      // 检查是否已存在相同哈希的版本
      final history = _histories[skillId];
      if (history != null) {
        final existingVersion = history.versions.lastWhere(
          (v) => v.bodyHash == bodyHash,
          orElse: () => SkillVersion(
            version: '',
            createdAt: DateTime.now(),
            bodyHash: '',
          ),
        );
        
        if (existingVersion.bodyHash == bodyHash) {
          debugPrint('[SkillVersionManager] 内容未变化，跳过版本注册');
          return false;
        }
      }
      
      // 创建新版本
      final newVersion = SkillVersion(
        version: version,
        changelog: changelog,
        createdAt: DateTime.now(),
        bodyHash: bodyHash,
        body: skill.body, // 可选：存储完整内容
      );
      
      // 更新或创建历史
      if (history == null) {
        _histories[skillId] = SkillVersionHistory(
          skillId: skillId,
          versions: [newVersion],
          currentVersion: version,
        );
      } else {
        history.versions.add(newVersion);
        if (compareVersions(version, history.currentVersion) > 0) {
          // 需要更新 currentVersion
          final updatedHistory = SkillVersionHistory(
            skillId: skillId,
            versions: history.versions,
            currentVersion: version,
          );
          _histories[skillId] = updatedHistory;
        }
      }
      
      await _saveToStorage();
      notifyListeners();
      
      debugPrint('[SkillVersionManager] 注册版本成功: $skillId@$version');
      return true;
    } catch (e) {
      debugPrint('[SkillVersionManager] 注册版本失败: $e');
      return false;
    }
  }

  /// 回滚到指定版本
  Future<Skill?> rollback(String skillId, String version) async {
    try {
      final history = _histories[skillId];
      if (history == null) return null;
      
      final targetVersion = history.versions.firstWhere(
        (v) => v.version == version,
        orElse: () => throw StateError('Version not found'),
      );
      
      if (targetVersion.body == null) {
        debugPrint('[SkillVersionManager] 版本 $version 没有存储完整内容');
        return null;
      }
      
      // 创建回滚后的技能
      final rolledBackSkill = Skill(
        id: skillId,
        metadata: SkillMetadata(
          name: skillId,
          description: 'Rolled back to $version',
        ),
        body: targetVersion.body!,
      );
      
      // 更新当前版本
      final updatedHistory = SkillVersionHistory(
        skillId: skillId,
        versions: history.versions,
        currentVersion: version,
      );
      _histories[skillId] = updatedHistory;
      
      await _saveToStorage();
      notifyListeners();
      
      debugPrint('[SkillVersionManager] 回滚成功: $skillId@$version');
      return rolledBackSkill;
    } catch (e) {
      debugPrint('[SkillVersionManager] 回滚失败: $e');
      return null;
    }
  }

  /// 获取版本列表
  List<SkillVersion> getVersionList(String skillId) {
    return _histories[skillId]?.versions ?? [];
  }

  /// 删除版本历史
  Future<void> deleteHistory(String skillId) async {
    _histories.remove(skillId);
    await _saveToStorage();
    notifyListeners();
  }

  /// 清理旧版本（保留最近 N 个）
  Future<void> cleanupOldVersions(String skillId, {int keepCount = 10}) async {
    final history = _histories[skillId];
    if (history == null || history.versions.length <= keepCount) return;
    
    // 保留最近的 N 个版本
    final updatedVersions = history.versions
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    updatedVersions.removeRange(keepCount, updatedVersions.length);
    
    final updatedHistory = SkillVersionHistory(
      skillId: skillId,
      versions: updatedVersions,
      currentVersion: history.currentVersion,
    );
    _histories[skillId] = updatedHistory;
    
    await _saveToStorage();
    notifyListeners();
    
    debugPrint('[SkillVersionManager] 清理了 ${history.versions.length - keepCount} 个旧版本');
  }

  /// 导出版本历史
  String exportHistory(String skillId) {
    final history = _histories[skillId];
    if (history == null) return '{}';
    
    return const JsonEncoder.withIndent('  ').convert(history.toJson());
  }

  /// 导入版本历史
  Future<bool> importHistory(String skillId, String jsonStr) async {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final history = SkillVersionHistory.fromJson(json);
      
      _histories[skillId] = history;
      await _saveToStorage();
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('[SkillVersionManager] 导入失败: $e');
      return false;
    }
  }
}

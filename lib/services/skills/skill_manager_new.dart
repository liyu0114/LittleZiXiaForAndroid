// Skill 状态管理
//
// 管理 Skill 的完整生命周期：待测试 -> 待安装 -> 已安装

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'skill_system.dart';
import 'clawhub_service.dart';
import 'skill_param_extractor.dart';

/// Skill 状态
enum SkillStatus {
  pendingTest,    // 待测试（从 ClawHub 同步的）
  testFailed,     // 测试失败
  pendingInstall, // 待安装（测试成功的）
  installed,      // 已安装
}

/// 托管的 Skill（带状态）
class ManagedSkill {
  final Skill skill;
  final SkillStatus status;
  final String? errorMessage;
  final DateTime? testedAt;
  final DateTime? installedAt;
  final String source; // 来源：clawhub, conversation, manual, builtin

  ManagedSkill({
    required this.skill,
    required this.status,
    this.errorMessage,
    this.testedAt,
    this.installedAt,
    this.source = 'manual',
  });

  ManagedSkill copyWith({
    Skill? skill,
    SkillStatus? status,
    String? errorMessage,
    DateTime? testedAt,
    DateTime? installedAt,
    String? source,
  }) {
    return ManagedSkill(
      skill: skill ?? this.skill,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      testedAt: testedAt ?? this.testedAt,
      installedAt: installedAt ?? this.installedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill': {
        'id': skill.id,
        'name': skill.metadata.name,
        'description': skill.metadata.description,
        'homepage': skill.metadata.homepage,
        'openclaw': skill.metadata.openclaw,
        'body': skill.body,
      },
      'status': status.name,
      'errorMessage': errorMessage,
      'testedAt': testedAt?.toIso8601String(),
      'installedAt': installedAt?.toIso8601String(),
      'source': source,
    };
  }

  factory ManagedSkill.fromJson(Map<String, dynamic> json) {
    final skillJson = json['skill'] as Map<String, dynamic>;
    return ManagedSkill(
      skill: Skill(
        id: skillJson['id'] as String,
        metadata: SkillMetadata(
          name: skillJson['name'] as String,
          description: skillJson['description'] as String,
          homepage: skillJson['homepage'] as String?,
          openclaw: skillJson['openclaw'] as Map<String, dynamic>?,
        ),
        body: skillJson['body'] as String,
      ),
      status: SkillStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SkillStatus.pendingTest,
      ),
      errorMessage: json['errorMessage'] as String?,
      testedAt: json['testedAt'] != null 
          ? DateTime.parse(json['testedAt']) 
          : null,
      installedAt: json['installedAt'] != null 
          ? DateTime.parse(json['installedAt']) 
          : null,
      source: (json['source'] as String?) ?? 'manual',
    );
  }
}

/// Skill 管理器（增强版）
class EnhancedSkillManager extends ChangeNotifier {
  static final EnhancedSkillManager _instance = EnhancedSkillManager._internal();
  factory EnhancedSkillManager() => _instance;
  EnhancedSkillManager._internal();

  // 基础管理器
  final SkillManager _baseManager = SkillManager();
  
  // ClawHub 服务
  final ClawHubService _clawhubService = ClawHubService();
  
  // 状态化的技能列表
  final List<ManagedSkill> _managedSkills = [];
  
  // 存储键
  static const String _storageKey = 'enhanced_skill_manager_v1';
  
  // 同步状态
  bool _isSyncing = false;
  String? _syncError;
  int _syncedCount = 0;
  
  // Getters
  SkillManager get baseManager => _baseManager;
  SkillRegistry get registry => _baseManager.registry;
  ClawHubService get clawhub => _clawhubService;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  int get syncedCount => _syncedCount;
  
  /// 获取各状态的技能
  List<ManagedSkill> get pendingTestSkills => 
      _managedSkills.where((s) => s.status == SkillStatus.pendingTest).toList();
  
  List<ManagedSkill> get testFailedSkills => 
      _managedSkills.where((s) => s.status == SkillStatus.testFailed).toList();
  
  List<ManagedSkill> get pendingInstallSkills => 
      _managedSkills.where((s) => s.status == SkillStatus.pendingInstall).toList();
  
  List<ManagedSkill> get installedManagedSkills => 
      _managedSkills.where((s) => s.status == SkillStatus.installed).toList();
  
  /// 获取内置技能（从 assets 加载的）
  List<Skill> get builtinSkills => _baseManager.registry.available;

  /// 初始化
  Future<void> initialize() async {
    debugPrint('[EnhancedSkillManager] 初始化...');
    
    // 1. 初始化基础管理器
    await _baseManager.initialize();
    debugPrint('[EnhancedSkillManager] 基础管理器初始化完成，内置技能: ${_baseManager.registry.length}');
    
    // 2. 加载托管的技能
    await _loadManagedSkills();
    debugPrint('[EnhancedSkillManager] 托管技能加载完成，总数: ${_managedSkills.length}');
    
    // 3. 预装内置技能（如果还没有被托管）
    await _preloadBuiltinSkills();
    debugPrint('[EnhancedSkillManager] 预装内置技能完成');
    
    notifyListeners();
  }
  
  /// 从本地存储加载托管的技能
  Future<void> _loadManagedSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr);
        _managedSkills.clear();
        
        for (final item in list) {
          try {
            final managed = ManagedSkill.fromJson(item as Map<String, dynamic>);
            _managedSkills.add(managed);
          } catch (e) {
            debugPrint('[EnhancedSkillManager] 加载技能失败: $e');
          }
        }
        
        debugPrint('[EnhancedSkillManager] 加载了 ${_managedSkills.length} 个托管技能');
      }
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 加载托管技能失败: $e');
    }
  }
  
  /// 预装内置技能
  Future<void> _preloadBuiltinSkills() async {
    final builtinSkills = _baseManager.registry.available;
    int preloadedCount = 0;
    
    for (final skill in builtinSkills) {
      // 检查是否已经托管
      final existingIndex = _managedSkills.indexWhere((s) => s.skill.id == skill.id);
      
      if (existingIndex == -1) {
        // 未托管，添加为已安装状态
        _managedSkills.add(ManagedSkill(
          skill: skill,
          status: SkillStatus.installed,
          source: 'builtin',
          installedAt: DateTime.now(),
        ));
        preloadedCount++;
      }
    }
    
    if (preloadedCount > 0) {
      debugPrint('[EnhancedSkillManager] 预装了 $preloadedCount 个内置技能');
      await _saveManagedSkills();
    }
  }
  
  /// 保存到本地存储
  Future<void> _saveManagedSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_managedSkills.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
      debugPrint('[EnhancedSkillManager] 保存了 ${_managedSkills.length} 个托管技能');
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 保存失败: $e');
    }
  }

  /// 从 ClawHub 同步技能
  Future<int> syncFromClawHub({bool mobileOnly = true, String? query}) async {
    _isSyncing = true;
    _syncError = null;
    _syncedCount = 0;
    notifyListeners();
    
    try {
      debugPrint('[EnhancedSkillManager] 开始从 ClawHub 同步...');
      
      int newCount = 0;
      
      // 搜索技能（使用成员变量 _clawhubService，避免重复创建）
      final skills = query != null && query.isNotEmpty
          ? await _clawhubService.search(query, limit: 20)
          : await _clawhubService.getPopularSkills(limit: 30);
      
      debugPrint('[EnhancedSkillManager] 获取到 ${skills.length} 个技能');
      
      for (final clawSkill in skills) {
        if (mobileOnly && !clawSkill.mobileFriendly) continue;
        
        final exists = _managedSkills.any((s) => s.skill.id == clawSkill.slug);
        if (exists) continue;
        
        // 获取技能内容
        final content = await _clawhubService.getSkillContent(clawSkill.slug);
        
        final skill = Skill(
          id: clawSkill.slug,
          metadata: SkillMetadata(
            name: clawSkill.name,
            description: clawSkill.description,
            homepage: clawSkill.homepage,
          ),
          body: content ?? '',
        );
        
        _managedSkills.add(ManagedSkill(
          skill: skill,
          status: SkillStatus.pendingTest,
          source: 'clawhub',
        ));
        newCount++;
      }
      
      await _saveManagedSkills();
      
      _isSyncing = false;
      _syncedCount = newCount;
      notifyListeners();
      
      debugPrint('[EnhancedSkillManager] 同步完成，新增 $newCount 个技能');
      return newCount;
      
    } catch (e) {
      _isSyncing = false;
      _syncError = e.toString();
      notifyListeners();
      
      debugPrint('[EnhancedSkillManager] 同步失败: $e');
      return 0;
    }
  }
  
  /// 搜索 ClawHub 技能
  Future<List<ClawHubSkill>> searchClawHub(String query) async {
    return _clawhubService.search(query, limit: 20);
  }
  
  /// 测试技能
  Future<bool> testSkill(ManagedSkill managedSkill, {Map<String, dynamic>? params}) async {
    debugPrint('[EnhancedSkillManager] 测试技能: ${managedSkill.skill.id}');
    
    try {
      final result = await _baseManager.executeSkill(
        managedSkill.skill, 
        params ?? {},
      );
      
      // 改进的成功判断：检查是否包含明确的失败标志
      final failurePatterns = [
        RegExp(r'^Error:', multiLine: true),
        RegExp(r'执行失败'),
        RegExp(r'HTTP [45]\d{2}'),
        RegExp(r'无法获取'),
        RegExp(r'权限'),
        RegExp(r'不支持'),
        RegExp(r'SocketException'),
        RegExp(r'TimeoutException'),
      ];
      
      final hasFailure = failurePatterns.any((p) => p.hasMatch(result));
      final success = result.isNotEmpty && !hasFailure;
      
      final index = _managedSkills.indexOf(managedSkill);
      if (index >= 0) {
        _managedSkills[index] = managedSkill.copyWith(
          status: success ? SkillStatus.pendingInstall : SkillStatus.testFailed,
          errorMessage: success ? null : result,
          testedAt: DateTime.now(),
        );
        
        await _saveManagedSkills();
      }
      
      notifyListeners();
      return success;
      
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 测试失败: $e');
      
      final index = _managedSkills.indexOf(managedSkill);
      if (index >= 0) {
        _managedSkills[index] = managedSkill.copyWith(
          status: SkillStatus.testFailed,
          errorMessage: _friendlyError(e.toString()),
          testedAt: DateTime.now(),
        );
        
        await _saveManagedSkills();
      }
      
      notifyListeners();
      return false;
    }
  }

  /// 安装技能
  Future<bool> installSkill(ManagedSkill managedSkill) async {
    debugPrint('[EnhancedSkillManager] 安装技能: ${managedSkill.skill.id}');
    
    try {
      // 注册到基础管理器
      _baseManager.installSkill(managedSkill.skill);
      
      // 更新状态
      final index = _managedSkills.indexOf(managedSkill);
      if (index >= 0) {
        _managedSkills[index] = managedSkill.copyWith(
          status: SkillStatus.installed,
          installedAt: DateTime.now(),
        );
        
        await _saveManagedSkills();
      }
      
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 安装失败: $e');
      return false;
    }
  }

  /// 卸载技能
  Future<bool> uninstallSkill(ManagedSkill managedSkill) async {
    debugPrint('[EnhancedSkillManager] 卸载技能: ${managedSkill.skill.id}');
    
    try {
      // 从基础管理器移除
      await _baseManager.uninstallSkill(managedSkill.skill.id);
      
      // 更新状态（回到待安装）
      final index = _managedSkills.indexOf(managedSkill);
      if (index >= 0) {
        _managedSkills[index] = managedSkill.copyWith(
          status: SkillStatus.pendingInstall,
          installedAt: null,
        );
        
        await _saveManagedSkills();
      }
      
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 卸载失败: $e');
      return false;
    }
  }

  /// 删除托管技能
  Future<void> removeManagedSkill(ManagedSkill managedSkill) async {
    _managedSkills.remove(managedSkill);
    await _saveManagedSkills();
    notifyListeners();
  }

  /// 从对话创建技能
  Future<ManagedSkill?> createSkillFromConversation({
    required String name,
    required String description,
    required String body,
  }) async {
    debugPrint('[EnhancedSkillManager] 从对话创建技能: $name');
    
    try {
      final skill = Skill(
        id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'),
        metadata: SkillMetadata(
          name: name,
          description: description,
        ),
        body: body,
      );
      
      final managed = ManagedSkill(
        skill: skill,
        status: SkillStatus.pendingTest,
        source: 'conversation',
      );
      
      _managedSkills.add(managed);
      await _saveManagedSkills();
      
      notifyListeners();
      return managed;
      
    } catch (e) {
      debugPrint('[EnhancedSkillManager] 创建技能失败: $e');
      return null;
    }
  }

  /// 更新技能内容
  Future<void> updateSkillContent(ManagedSkill managedSkill, String newBody) async {
    final index = _managedSkills.indexOf(managedSkill);
    if (index >= 0) {
      final updatedSkill = Skill(
        id: managedSkill.skill.id,
        metadata: managedSkill.skill.metadata,
        body: newBody,
      );
      
      _managedSkills[index] = managedSkill.copyWith(
        skill: updatedSkill,
        status: SkillStatus.pendingTest, // 修改后需要重新测试
        errorMessage: null,
      );
      
      await _saveManagedSkills();
      notifyListeners();
    }
  }

  /// 执行技能
  Future<String> executeSkill(Skill skill, Map<String, dynamic> params) async {
    return _baseManager.executeSkill(skill, params);
  }
  
  /// 匹配技能
  List<Skill> matchSkills(String message) {
    return _baseManager.matchSkills(message);
  }
  
  /// 提取技能参数
  ExtractedParams extractParams(Skill skill) {
    return SkillParamExtractor.extract(skill.body);
  }
  
  /// 提取技能参数（从 ManagedSkill）
  ExtractedParams extractParamsFromManaged(ManagedSkill managedSkill) {
    return SkillParamExtractor.extract(managedSkill.skill.body);
  }
  
  /// 生成测试参数
  Map<String, dynamic> generateTestParams(Skill skill) {
    final extracted = SkillParamExtractor.extract(skill.body);
    return SkillParamExtractor.generateTestValues(extracted.params);
  }
  
  /// 设置 Gateway 配置
  void setGatewayConfig(String url, {String? token}) {
    _clawhubService.setGateway(url, token: token);
  }
  
  /// 友好化错误信息
  String _friendlyError(String error) {
    // 网络错误
    if (error.contains('SocketException') || error.contains('Connection refused')) {
      return '网络连接失败，请检查网络设置';
    }
    if (error.contains('TimeoutException') || error.contains('timed out')) {
      return '请求超时，请稍后重试';
    }
    if (error.contains('Connection closed')) {
      return '连接已断开，请重试';
    }
    
    // HTTP 错误
    if (error.contains('404')) {
      return '资源不存在';
    }
    if (error.contains('401') || error.contains('403')) {
      return '没有访问权限';
    }
    if (error.contains('500') || error.contains('502') || error.contains('503')) {
      return '服务器暂时不可用，请稍后重试';
    }
    
    // 权限错误
    if (error.contains('Permission') || error.contains('权限')) {
      return '缺少必要权限，请在设置中授权';
    }
    if (error.contains('Location')) {
      return '无法获取位置，请授予位置权限';
    }
    
    // 格式错误
    if (error.contains('FormatException') || error.contains('JSON')) {
      return '数据格式错误';
    }
    
    // 默认：简化技术信息
    // 去掉 Exception 类型前缀
    final cleaned = error
        .replaceFirst(RegExp(r'^[A-Z][a-zA-Z]+Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '');
    
    // 如果还是太长，截断
    if (cleaned.length > 50) {
      return '${cleaned.substring(0, 50)}...';
    }
    
    return cleaned.isEmpty ? '操作失败，请稍后重试' : cleaned;
  }
}

// 技能自造服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 分析结果（从 skill_auto_creator.dart 复制）
class AnalysisResult {
  final bool needNew;
  final String reason;
  final String skillType;

  AnalysisResult({
    required this.needNew,
    required this.reason,
    required this.skillType,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      needNew: json['needNew'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      skillType: json['skillType'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() => {
    'needNew': needNew,
    'reason': reason,
    'skillType': skillType,
  };
}

/// 技能元数据（从 skill_manager_new.dart 复制）
class SkillMeta {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final DateTime createdAt;
  final List<String> tags;
  final bool isBuiltIn;

  SkillMeta({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author = 'unknown',
    DateTime? createdAt,
    this.tags = const [],
    this.isBuiltIn = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SkillMeta.fromJson(Map<String, dynamic> json) {
    return SkillMeta(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'unknown',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
    'isBuiltIn': isBuiltIn,
  };
}

/// 技能（从 skill_system.dart 复制）
class Skill {
  final SkillMeta meta;
  final Map<String, dynamic> config;
  final List<String> requiredCapabilities;

  Skill({
    required this.meta,
    this.config = const {},
    this.requiredCapabilities = const [],
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      meta: SkillMeta.fromJson(json['meta'] as Map<String, dynamic>? ?? {}),
      config: json['config'] as Map<String, dynamic>? ?? {},
      requiredCapabilities:
          (json['requiredCapabilities'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'meta': meta.toJson(),
    'config': config,
    'requiredCapabilities': requiredCapabilities,
  };
}

void main() {
  group('L1-02 技能自造服务测试', () {
    
    test('测试1：AnalysisResult 创建 - 需要新Skill', () {
      final result = AnalysisResult(
        needNew: true,
        reason: '需要计算器功能',
        skillType: 'skill',
      );
      expect(result.needNew, true);
      expect(result.skillType, 'skill');
    });
    
    test('测试2：AnalysisResult 创建 - 不需要新Skill', () {
      final result = AnalysisResult(
        needNew: false,
        reason: '现有工具已完成',
        skillType: 'none',
      );
      expect(result.needNew, false);
      expect(result.reason, '现有工具已完成');
    });
    
    test('测试3：SkillMeta 创建', () {
      final meta = SkillMeta(
        id: 'test_skill_001',
        name: '测试技能',
        description: '这是一个测试技能',
      );
      expect(meta.id, 'test_skill_001');
      expect(meta.name, '测试技能');
      expect(meta.version, '1.0.0');
    });
    
    test('测试4：SkillMeta JSON序列化', () {
      final meta = SkillMeta(
        id: 'test_skill',
        name: '测试技能',
        description: '描述',
        tags: ['test', 'demo'],
      );
      
      final json = meta.toJson();
      expect(json['id'], 'test_skill');
      expect(json['tags'], ['test', 'demo']);
      
      final restored = SkillMeta.fromJson(json);
      expect(restored.id, 'test_skill');
      expect(restored.tags.length, 2);
    });
    
    test('测试5：Skill 创建', () {
      final meta = SkillMeta(
        id: 'test_skill',
        name: '测试技能',
        description: '描述',
      );
      final skill = Skill(
        meta: meta,
        config: {'enabled': true},
        requiredCapabilities: ['file_read'],
      );
      
      expect(skill.meta.id, 'test_skill');
      expect(skill.config['enabled'], true);
      expect(skill.requiredCapabilities, ['file_read']);
    });
    
    test('测试6：Skill JSON序列化', () {
      final meta = SkillMeta(
        id: 'test_skill',
        name: '测试技能',
        description: '描述',
      );
      final skill = Skill(
        meta: meta,
        config: {'enabled': true},
      );
      
      final json = skill.toJson();
      expect(json['meta']['id'], 'test_skill');
      expect(json['config']['enabled'], true);
      
      final restored = Skill.fromJson(json);
      expect(restored.meta.id, 'test_skill');
    });
    
    test('测试7：技能标签操作', () {
      final meta = SkillMeta(
        id: 'test',
        name: '测试',
        description: '描述',
        tags: ['ai', 'tool'],
      );
      
      // 添加标签
      final newTags = [...meta.tags, 'network'];
      expect(newTags.length, 3);
      expect(newTags.contains('network'), true);
      
      // 删除标签
      final filteredTags = newTags.where((t) => t != 'tool').toList();
      expect(filteredTags.length, 2);
    });
    
    test('测试8：内置技能标识', () {
      final builtIn = SkillMeta(
        id: 'builtin_weather',
        name: '天气',
        description: '内置天气技能',
        isBuiltIn: true,
      );
      
      final user = SkillMeta(
        id: 'user_skill',
        name: '用户技能',
        description: '用户创建',
        isBuiltIn: false,
      );
      
      expect(builtIn.isBuiltIn, true);
      expect(user.isBuiltIn, false);
    });
    
    test('测试9：技能版本管理', () {
      final v1 = SkillMeta(
        id: 'test',
        name: '测试',
        description: '描述',
        version: '1.0.0',
      );
      final v2 = SkillMeta(
        id: 'test',
        name: '测试',
        description: '描述',
        version: '1.0.1',
      );
      
      expect(v1.version, '1.0.0');
      expect(v2.version, '1.0.1');
    });
    
    test('测试10：技能配置灵活性', () {
      final skill = Skill(
        meta: SkillMeta(id: 'test', name: '测试', description: 'desc'),
        config: {
          'timeout': 30,
          'retries': 3,
          'options': {'verbose': true},
        },
      );
      
      expect(skill.config['timeout'], 30);
      expect(skill.config['options']['verbose'], true);
    });
  });
}
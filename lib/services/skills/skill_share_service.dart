// 技能分享服务
//
// 支持导出、导入、分享技能

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'skill_system.dart';

/// 技能分享格式
class ShareableSkill {
  final String version;
  final String id;
  final String name;
  final String description;
  final String? homepage;
  final String body;
  final DateTime createdAt;
  final String? author;
  final List<String> tags;

  ShareableSkill({
    this.version = '1.0',
    required this.id,
    required this.name,
    required this.description,
    this.homepage,
    required this.body,
    DateTime? createdAt,
    this.author,
    this.tags = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory ShareableSkill.fromSkill(Skill skill, {String? author}) {
    return ShareableSkill(
      id: skill.id,
      name: skill.metadata.name,
      description: skill.metadata.description,
      homepage: skill.metadata.homepage,
      body: skill.body,
      author: author,
    );
  }

  factory ShareableSkill.fromJson(Map<String, dynamic> json) {
    return ShareableSkill(
      version: json['version'] ?? '1.0',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      homepage: json['homepage'],
      body: json['body'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      author: json['author'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'description': description,
    'homepage': homepage,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'author': author,
    'tags': tags,
  };

  Skill toSkill() {
    return Skill(
      id: id,
      metadata: SkillMetadata(
        name: name,
        description: description,
        homepage: homepage,
      ),
      body: body,
    );
  }

  /// 转换为 JSON 字符串（用于分享）
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// 转换为 Base64（用于二维码）
  String toBase64() => base64Encode(utf8.encode(toJsonString()));
}

/// 技能分享服务
class SkillShareService {
  /// 导出技能为 JSON 文件
  Future<File?> exportToFile(Skill skill, {String? author}) async {
    try {
      final shareable = ShareableSkill.fromSkill(skill, author: author);
      final jsonStr = shareable.toJsonString();

      // 获取保存目录
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${skill.id}_skill.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonStr);
      
      debugPrint('[SkillShareService] 导出成功: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[SkillShareService] 导出失败: $e');
      return null;
    }
  }

  /// 通过系统分享功能分享技能
  Future<bool> shareSkill(Skill skill, {String? author}) async {
    try {
      final shareable = ShareableSkill.fromSkill(skill, author: author);
      final jsonStr = shareable.toJsonString();

      // 先保存到临时文件
      final directory = await getTemporaryDirectory();
      final fileName = '${skill.id}_skill.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '小紫霞技能: ${skill.metadata.name}',
        text: '技能: ${skill.metadata.name}\n${skill.metadata.description}',
      );

      return true;
    } catch (e) {
      debugPrint('[SkillShareService] 分享失败: $e');
      return false;
    }
  }

  /// 从文件导入技能
  Future<ShareableSkill?> importFromFile(File file) async {
    try {
      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final skill = ShareableSkill.fromJson(json);
      debugPrint('[SkillShareService] 导入成功: ${skill.name}');
      return skill;
    } catch (e) {
      debugPrint('[SkillShareService] 导入失败: $e');
      return null;
    }
  }

  /// 从 JSON 字符串导入
  ShareableSkill? importFromJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ShareableSkill.fromJson(json);
    } catch (e) {
      debugPrint('[SkillShareService] 解析失败: $e');
      return null;
    }
  }

  /// 从 Base64 导入
  ShareableSkill? importFromBase64(String base64Str) {
    try {
      final jsonStr = utf8.decode(base64Decode(base64Str));
      return importFromJson(jsonStr);
    } catch (e) {
      debugPrint('[SkillShareService] Base64 解码失败: $e');
      return null;
    }
  }

  /// 生成分享链接（需要服务器支持）
  Future<String?> generateShareLink(Skill skill, {String? author}) async {
    try {
      final shareable = ShareableSkill.fromSkill(skill, author: author);
      
      // TODO: 调用服务器 API 生成短链接
      // 暂时返回 base64 编码的 JSON
      final base64 = shareable.toBase64();
      return 'littlezixia://skill?data=$base64';
    } catch (e) {
      debugPrint('[SkillShareService] 生成链接失败: $e');
      return null;
    }
  }

  /// 从剪贴板导入
  Future<ShareableSkill?> importFromClipboard() async {
    try {
      // TODO: 使用 clipboard_watcher 或其他剪贴板库
      // 暂时返回 null
      return null;
    } catch (e) {
      debugPrint('[SkillShareService] 从剪贴板导入失败: $e');
      return null;
    }
  }
}

/// 技能分享卡片数据
class SkillShareCard {
  final String title;
  final String description;
  final String skillData; // Base64 编码的技能数据
  final String? previewCode; // 预览代码片段

  SkillShareCard({
    required this.title,
    required this.description,
    required this.skillData,
    this.previewCode,
  });

  String toMarkdown() {
    return '''
# $title

$description

## 使用方法

1. 复制下面的技能数据
2. 在小紫霞 APP 中打开技能管理
3. 点击"导入技能"
4. 粘贴技能数据

## 技能数据

```
$skillData
```

---
*由小紫霞生成*
''';
  }
}

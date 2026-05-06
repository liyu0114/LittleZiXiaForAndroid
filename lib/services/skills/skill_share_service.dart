// 技能分享服务
//
// 支持导出、导入、分享技能

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  ShareableSkill({
    this.version = '1.0',
    required this.id,
    required this.name,
    required this.description,
    this.homepage,
    required this.body,
    DateTime? createdAt,
    this.author,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从 Skill 转换
  factory ShareableSkill.fromSkill(Skill skill, {String? author}) {
    return ShareableSkill(
      id: skill.metadata.name,
      name: skill.metadata.name,
      description: skill.metadata.description,
      homepage: skill.metadata.homepage,
      body: skill.body,
      author: author,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'description': description,
    'homepage': homepage,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'author': author,
  };

  /// 从 JSON 解析
  factory ShareableSkill.fromJson(Map<String, dynamic> json) {
    return ShareableSkill(
      version: json['version'] ?? '1.0',
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      homepage: json['homepage'],
      body: json['body'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      author: json['author'],
    );
  }

  /// 转换为 Base64
  String toBase64() {
    return base64Encode(utf8.encode(jsonEncode(toJson())));
  }

  /// 从 Base64 解析
  factory ShareableSkill.fromBase64(String base64Str) {
    try {
      final json = jsonDecode(utf8.decode(base64Decode(base64Str)));
      return ShareableSkill.fromJson(json);
    } catch (e) {
      throw FormatException('无效的分享数据: $e');
    }
  }

  /// 导出为 Markdown
  String toMarkdown() {
    return '''
# $name

$description

## 代码

\`\`\`json
$body
\`\`\`

---
由 小紫霞 v$version 创建
''';
  }
}

/// 技能分享服务
class SkillShareService {
  /// 分享技能
  Future<void> shareSkill(Skill skill) async {
    final shareable = ShareableSkill.fromSkill(skill);
    final markdown = shareable.toMarkdown();
    await Share.share(markdown, subject: skill.metadata.name);
  }

  /// 分享 JSON 内容
  Future<void> shareJson(Skill skill) async {
    final shareable = ShareableSkill.fromSkill(skill);
    await Share.share(shareable.toJson().toString(), subject: skill.metadata.name);
  }

  /// 从分享数据导入
  Future<ShareableSkill?> importFromShare(String data) async {
    try {
      // 尝试解析为 JSON
      final json = jsonDecode(data);
      return ShareableSkill.fromJson(json);
    } catch (e1) {
      try {
        // 尝试解析为 Base64
        return ShareableSkill.fromBase64(data);
      } catch (e2) {
        debugPrint('[SkillShareService] 导入失败: $e2');
        return null;
      }
    }
  }

  /// 从剪贴板导入
  Future<ShareableSkill?> importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        return importFromShare(data.text!);
      }
      return null;
    } catch (e) {
      debugPrint('[SkillShareService] 从剪贴板导入失败: $e');
      return null;
    }
  }

  /// 导出到文件
  Future<String?> exportToFile(Skill skill) async {
    try {
      final shareable = ShareableSkill.fromSkill(skill);
      final json = shareable.toJson();
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${skill.metadata.name}.skill.json');
      await file.writeAsString(jsonEncode(json));
      
      return file.path;
    } catch (e) {
      debugPrint('[SkillShareService] 导出失败: $e');
      return null;
    }
  }

  /// 从文件导入
  Future<ShareableSkill?> importFromFile(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      return importFromShare(content);
    } catch (e) {
      debugPrint('[SkillShareService] 导入失败: $e');
      return null;
    }
  }
}
// Markdown Skill 解析器
//
// 从 SKILL.md 文件解析出指令和元数据

import 'package:flutter/foundation.dart';
import 'skill_instruction.dart';

/// Skill 元数据
class SkillMetadata {
  final String name;
  final String description;
  final String? homepage;
  final Map<String, dynamic> extra;

  SkillMetadata({
    required this.name,
    required this.description,
    this.homepage,
    this.extra = const {},
  });

  factory SkillMetadata.fromYaml(String yaml) {
    // 简化的 YAML frontmatter 解析
    String name = '';
    String description = '';
    String? homepage;
    Map<String, dynamic> extra = {};

    final lines = yaml.split('\n');
    for (final line in lines) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;

      final key = line.substring(0, colonIndex).trim();
      var value = line.substring(colonIndex + 1).trim();

      // 移除引号
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      switch (key) {
        case 'name':
          name = value;
          break;
        case 'description':
          description = value;
          break;
        case 'homepage':
          homepage = value;
          break;
        default:
          extra[key] = value;
      }
    }

    return SkillMetadata(
      name: name,
      description: description,
      homepage: homepage,
      extra: extra,
    );
  }
}

/// 解析后的 Skill
class ParsedSkill {
  final SkillMetadata metadata;
  final List<SkillInstruction> instructions;
  final String rawMarkdown;

  ParsedSkill({
    required this.metadata,
    required this.instructions,
    required this.rawMarkdown,
  });
}

/// Markdown Skill 解析器
class MarkdownSkillParser {
  /// 解析 SKILL.md 内容
  static ParsedSkill parse(String markdown) {
    // 1. 解析 frontmatter
    final frontmatterMatch = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n').firstMatch(markdown);
    
    String frontmatter = '';
    String content = markdown;
    
    if (frontmatterMatch != null) {
      frontmatter = frontmatterMatch.group(1)!;
      content = markdown.substring(frontmatterMatch.end);
    }

    // 2. 解析元数据
    final metadata = SkillMetadata.fromYaml(frontmatter);

    // 3. 解析代码块
    final instructions = <SkillInstruction>[];
    final codeBlockRegex = RegExp(r'```(\w+)?\s*\n([\s\S]*?)\n```');
    
    for (final match in codeBlockRegex.allMatches(content)) {
      final language = match.group(1) ?? 'text';
      final code = match.group(2)!;
      
      instructions.add(
        SkillInstruction.fromCodeBlock(language, code),
      );
    }

    return ParsedSkill(
      metadata: metadata,
      instructions: instructions,
      rawMarkdown: markdown,
    );
  }

  /// 提取第一个可执行的指令
  static SkillInstruction? extractPrimaryInstruction(ParsedSkill skill) {
    // 优先级：http > dart > bash > other
    for (final instruction in skill.instructions) {
      if (instruction is HttpInstruction) {
        return instruction;
      }
    }
    
    for (final instruction in skill.instructions) {
      if (instruction is DartInstruction) {
        return instruction;
      }
    }
    
    for (final instruction in skill.instructions) {
      if (instruction is BashInstruction) {
        return instruction;
      }
    }
    
    return skill.instructions.isNotEmpty ? skill.instructions.first : null;
  }

  /// 检查 Skill 是否适合在移动端执行
  static bool isMobileCompatible(ParsedSkill skill) {
    for (final instruction in skill.instructions) {
      if (instruction is BashInstruction) {
        // 大部分 bash 指令在移动端不可用
        // 除非是简单的命令（如 echo、date 等）
        return false;
      }
    }
    return true;
  }

  /// 获取 Skill 的使用示例
  static List<String> extractExamples(String markdown) {
    final examples = <String>[];
    
    // 查找示例部分
    final exampleSection = RegExp(
      r'##\s*(?:Example|Usage|使用示例)[\s\S]*?(?=##|$)',
      caseSensitive: false,
    ).firstMatch(markdown);
    
    if (exampleSection != null) {
      final content = exampleSection.group(0)!;
      // 提取代码块
      final codeBlockRegex = RegExp(r'```(?:bash|sh|shell)?\s*\n([\s\S]*?)\n```');
      for (final match in codeBlockRegex.allMatches(content)) {
        examples.add(match.group(1)!);
      }
    }
    
    return examples;
  }
}

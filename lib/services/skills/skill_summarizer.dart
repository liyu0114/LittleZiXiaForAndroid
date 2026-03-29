// Skill 总结服务
//
// 从对话历史中分析并提取可复用的 Skill

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../llm/llm_base.dart';

/// 自定义 Skill 定义
class CustomSkill {
  final String id;
  final String name;
  final String description;
  final List<String> triggers;
  final String pattern;
  final Map<String, String> params;
  final String template;
  final DateTime createdAt;

  CustomSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.triggers,
    required this.pattern,
    required this.params,
    required this.template,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CustomSkill.fromJson(Map<String, dynamic> json) {
    return CustomSkill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      triggers: List<String>.from(json['triggers'] as List),
      pattern: json['pattern'] as String,
      params: Map<String, String>.from(json['params'] as Map),
      template: json['template'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'triggers': triggers,
      'pattern': pattern,
      'params': params,
      'template': template,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'CustomSkill(id: $id, name: $name, triggers: $triggers)';
}

/// SKILL.md 生成结果
class GeneratedSkill {
  final String name;
  final String description;
  final String body;
  final String? explanation;

  GeneratedSkill({
    required this.name,
    required this.description,
    required this.body,
    this.explanation,
  });

  String toSkillMarkdown() {
    return '''---
name: $name
description: "$description"
---

$body''';
  }
}

/// Skill 总结服务
class SkillSummarizer {
  final LLMProvider _llmProvider;

  SkillSummarizer(this._llmProvider);

  /// 从对话历史中总结 Skill
  Future<CustomSkill?> summarizeFromConversation(List<Map<String, String>> messages) async {
    if (messages.isEmpty) {
      debugPrint('[SkillSummarizer] 对话历史为空');
      return null;
    }

    try {
      final conversationText = messages.map((msg) {
        final role = msg['role'] == 'user' ? '用户' : '助手';
        return '$role: ${msg['content']}';
      }).join('\n');

      final prompt = '''
分析以下对话历史，识别出可复用的模式，并将其定义为一个 Skill。

对话历史：
$conversationText

请以 JSON 格式返回 Skill 定义：
{
  "name": "Skill 名称（简洁，2-4字）",
  "description": "Skill 描述（一句话说明功能）",
  "triggers": ["触发词1", "触发词2"],
  "pattern": "匹配模式（正则表达式）",
  "params": {"param1": "参数1说明"},
  "template": "回复模板（使用 {param1} 等占位符）"
}

如果没有可复用的模式，返回 {"name": null}
只返回 JSON，不要有其他文字。
''';

      final llmMessages = [
        ChatMessage.system('你是一个 Skill 分析专家。'),
        ChatMessage.user(prompt),
      ];

      final stream = _llmProvider.chatStream(llmMessages);
      final buffer = StringBuffer();

      await for (final event in stream) {
        if (event.done || event.error != null) break;
        if (event.delta != null) buffer.write(event.delta);
      }

      final response = buffer.toString().trim();
      debugPrint('[SkillSummarizer] LLM 响应: $response');

      var jsonStr = response;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      jsonStr = jsonStr.trim();

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (json['name'] == null) {
        debugPrint('[SkillSummarizer] 没有识别到可复用的模式');
        return null;
      }

      final skill = CustomSkill(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String,
        description: json['description'] as String,
        triggers: List<String>.from(json['triggers'] as List),
        pattern: json['pattern'] as String,
        params: Map<String, String>.from(json['params'] as Map),
        template: json['template'] as String,
      );

      debugPrint('[SkillSummarizer] 成功总结 Skill: ${skill.name}');
      return skill;
    } catch (e) {
      debugPrint('[SkillSummarizer] 总结失败: $e');
      return null;
    }
  }

  /// 从对话生成 SKILL.md 格式的技能
  Future<GeneratedSkill?> generateSkillMarkdown(String conversation) async {
    if (conversation.trim().isEmpty) {
      debugPrint('[SkillSummarizer] 对话内容为空');
      return null;
    }

    try {
      final prompt = '''
分析以下对话，提取可复用的技能模式，生成 SKILL.md 格式。

对话内容：
$conversation

返回格式示例：
{
  "name": "skill_name",
  "description": "技能描述",
  "body": "技能说明文字\\n\\n```http\\nGET https://api.example.com/{param}\\n```",
  "explanation": "简要说明"
}

规则：
1. 只提取可复用的模式
2. HTTP API 使用 wttr.in、Open-Meteo 等公开 API
3. 参数用 {param} 格式
4. 没有可复用模式返回 {"name": null}

只返回 JSON。
''';

      final llmMessages = [
        ChatMessage.system('你是 Skill 生成专家，从对话中提取可复用模式并生成 SKILL.md 格式。'),
        ChatMessage.user(prompt),
      ];

      final stream = _llmProvider.chatStream(llmMessages);
      final buffer = StringBuffer();

      await for (final event in stream) {
        if (event.done || event.error != null) break;
        if (event.delta != null) buffer.write(event.delta);
      }

      final response = buffer.toString().trim();
      debugPrint('[SkillSummarizer] LLM 响应: $response');

      var jsonStr = response;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      jsonStr = jsonStr.trim();

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (json['name'] == null) {
        debugPrint('[SkillSummarizer] 没有识别到可复用的模式');
        return null;
      }

      return GeneratedSkill(
        name: json['name'] as String,
        description: json['description'] as String,
        body: json['body'] as String,
        explanation: json['explanation'] as String?,
      );
    } catch (e) {
      debugPrint('[SkillSummarizer] 生成失败: $e');
      return null;
    }
  }

  Future<void> saveCustomSkill(CustomSkill skill) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      skillsList.add(skill.toJson());
      await prefs.setString('custom_skills', jsonEncode(skillsList));
      debugPrint('[SkillSummarizer] 已保存 Skill: ${skill.name}');
    } catch (e) {
      debugPrint('[SkillSummarizer] 保存失败: $e');
    }
  }

  Future<List<CustomSkill>> loadCustomSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      final skills = skillsList
          .map((json) => CustomSkill.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('[SkillSummarizer] 已加载 ${skills.length} 个自定义 Skills');
      return skills;
    } catch (e) {
      debugPrint('[SkillSummarizer] 加载失败: $e');
      return [];
    }
  }

  Future<void> deleteCustomSkill(String skillId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      skillsList.removeWhere((json) => (json as Map<String, dynamic>)['id'] == skillId);
      await prefs.setString('custom_skills', jsonEncode(skillsList));
      debugPrint('[SkillSummarizer] 已删除 Skill: $skillId');
    } catch (e) {
      debugPrint('[SkillSummarizer] 删除失败: $e');
    }
  }
}

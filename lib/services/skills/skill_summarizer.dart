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
  final List<String> triggers;    // 触发词
  final String pattern;           // 匹配模式
  final Map<String, String> params; // 参数定义
  final String template;          // 回复模板
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
  String toString() {
    return 'CustomSkill(id: $id, name: $name, triggers: $triggers)';
  }
}

/// Skill 总结服务
class SkillSummarizer {
  final LLMProvider _llmProvider;

  SkillSummarizer(this._llmProvider);

  /// 从对话历史中总结 Skill
  Future<CustomSkill?> summarizeFromConversation(
    List<Map<String, String>> messages,
  ) async {
    if (messages.isEmpty) {
      debugPrint('[SkillSummarizer] 对话历史为空');
      return null;
    }

    try {
      // 构建对话摘要
      final conversationText = messages.map((msg) {
        final role = msg['role'] == 'user' ? '用户' : '助手';
        return '$role: ${msg['content']}';
      }).join('\n');

      // 构建 LLM 提示词
      final prompt = '''
分析以下对话历史，识别出可复用的模式，并将其定义为一个 Skill。

对话历史：
$conversationText

请以 JSON 格式返回 Skill 定义：
{
  "name": "Skill 名称（简洁，2-4字）",
  "description": "Skill 描述（一句话说明功能）",
  "triggers": ["触发词1", "触发词2", "触发词3"],
  "pattern": "匹配模式（正则表达式）",
  "params": {
    "param1": "参数1说明",
    "param2": "参数2说明"
  },
  "template": "回复模板（使用 {param1} 等占位符）"
}

规则：
1. 只提取真正可复用的模式（不是一次性对话）
2. 触发词要具体（如"翻译"、"计算"、"查询天气"）
3. 模式要简洁但准确
4. 参数要合理（不要太多）
5. 模板要包含必要的占位符

如果没有可复用的模式，返回：
{
  "name": null
}

只返回 JSON，不要有其他文字。
''';

      // 调用 LLM
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

      // 解析 JSON
      var jsonStr = response;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 检查是否有效
      if (json['name'] == null) {
        debugPrint('[SkillSummarizer] 没有识别到可复用的模式');
        return null;
      }

      // 创建 CustomSkill
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

  /// 保存自定义 Skill
  Future<void> saveCustomSkill(CustomSkill skill) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载已有的 Skills
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      
      // 添加新 Skill
      skillsList.add(skill.toJson());
      
      // 保存
      await prefs.setString('custom_skills', jsonEncode(skillsList));
      
      debugPrint('[SkillSummarizer] 已保存 Skill: ${skill.name}');
    } catch (e) {
      debugPrint('[SkillSummarizer] 保存失败: $e');
    }
  }

  /// 加载所有自定义 Skills
  Future<List<CustomSkill>> loadCustomSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      
      final skills = skillsList.map((json) {
        return CustomSkill.fromJson(json as Map<String, dynamic>);
      }).toList();
      
      debugPrint('[SkillSummarizer] 已加载 ${skills.length} 个自定义 Skills');
      return skills;
    } catch (e) {
      debugPrint('[SkillSummarizer] 加载失败: $e');
      return [];
    }
  }

  /// 删除自定义 Skill
  Future<void> deleteCustomSkill(String skillId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString('custom_skills') ?? '[]';
      final skillsList = jsonDecode(skillsJson) as List;
      
      // 移除指定 Skill
      skillsList.removeWhere((json) {
        final skill = json as Map<String, dynamic>;
        return skill['id'] == skillId;
      });
      
      // 保存
      await prefs.setString('custom_skills', jsonEncode(skillsList));
      
      debugPrint('[SkillSummarizer] 已删除 Skill: $skillId');
    } catch (e) {
      debugPrint('[SkillSummarizer] 删除失败: $e');
    }
  }
}

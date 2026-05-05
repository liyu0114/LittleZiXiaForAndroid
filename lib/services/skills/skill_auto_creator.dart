// 技能自造服务 - 自动创建新Skill
//
// 当没有现成工具时，根据用户需求自动创建Skill

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'skill_manager_new.dart';
import '../llm/llm_base.dart';

/// 技能自造服务
class SkillAutoCreator extends ChangeNotifier {
  final SkillManager _skillManager;
  final LLMProvider _llmProvider;
  
  bool _isCreating = false;
  
  SkillAutoCreator({
    required SkillManager skillManager,
    required LLMProvider llmProvider,
  }) : _skillManager = skillManager,
       _llmProvider = llmProvider;
  
  bool get isCreating => _isCreating;
  
  /// 分析用户需求，判断是否需要新Skill
  Future<AnalysisResult> analyzeNeed(String userNeed) async {
    final prompt = '''
分析用户需求是否需要创建新Skill：

用户需求：$userNeed

请分析：
1. 用户想要什么功能？
2. 需要什么输入？
3. 需要什么输出？
4. 现有工具是否能完成？

返回JSON格式：
{
  "needNew": true/false,
  "reason": "原因",
  "skillType": "skill/script/app/none"
}
''';

    try {
      final response = await _llmProvider.chat([
        ChatMessage.system('你是一个Skill创建助手'),
        ChatMessage.user(prompt),
      ]);
      
      final result = _parseAnalysis(response.content);
      return result;
    } catch (e) {
      return AnalysisResult(
        needNew: false,
        reason: e.toString(),
        skillType: 'none',
      );
    }
  }
  
  /// 创建新Skill
  Future<Skill?> createSkill(String userNeed) async {
    _isCreating = true;
    notifyListeners();
    
    try {
      debugPrint('[SkillAutoCreator] 分析需求: $userNeed');
      
      // 1. 分析需求
      final analysis = await analyzeNeed(userNeed);
      if (!analysis.needNew) {
        debugPrint('[SkillAutoCreator] 不需要新Skill: ${analysis.reason}');
        return null;
      }
      
      // 2. 生成Skill代码
      debugPrint('[SkillAutoCreator] 生成Skill代码...');
      final code = await _generateSkillCode(userNeed, analysis.skillType);
      
      // 3. 生成Skill ID
      final skillId = 'auto_${DateTime.now().millisecondsSinceEpoch}';
      
      // 4. 创建Skill对象
      final skill = Skill(
        id: skillId,
        name: _generateName(userNeed),
        instruction: userNeed,
        code: code,
        createdAt: DateTime.now(),
      );
      
      // 5. 注册到系统
      debugPrint('[SkillAutoCreator] 注册Skill: ${skill.id}');
      await _skillManager.register(skill);
      
      debugPrint('[SkillAutoCreator] 创建完成: ${skill.id}');
      return skill;
    } catch (e) {
      debugPrint('[SkillAutoCreator] 错误: $e');
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }
  
  /// 生成Skill代码
  Future<String> _generateSkillCode(String need, String type) async {
    final prompt = '''
请生成一个简单的Skill代码：

用户需求：$need

请生成Flutter/Dart代码：
- 继承Skill基类
- 实现execute方法
- 返回SimpleResponse

只需要返回代码，不要其他内容。
''';

    try {
      final response = await _llmProvider.chat([
        ChatMessage.system('你是一个Skill代码生成助手'),
        ChatMessage.user(prompt),
      ]);
      
      return response.content;
    } catch (e) {
      return '// Error: $e';
    }
  }
  
  /// 生成Skill名称
  String _generateName(String need) {
    // 简单提取关键词作为名称
    final words = need.split(' ').take(3).join('_');
    return 'auto_$words';
  }
  
  /// 解析分析结果
  AnalysisResult _parseAnalysis(String content) {
    try {
      // 尝试提取JSON
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(content);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return AnalysisResult(
          needNew: json['needNew'] ?? false,
          reason: json['reason'] ?? '',
          skillType: json['skillType'] ?? 'skill',
        );
      }
    } catch (e) {
      debugPrint('[SkillAutoCreator] 解析错误: $e');
    }
    
    return AnalysisResult(
      needNew: false,
      reason: '无法解析',
      skillType: 'none',
    );
  }
}

/// 分析结果
class AnalysisResult {
  final bool needNew;
  final String reason;
  final String skillType;
  
  AnalysisResult({
    required this.needNew,
    required this.reason,
    required this.skillType,
  });
}
/// 技能状态管理
class SkillState {
  final Map skillRegistry;
  final List enabledSkills;
  final List customSkills;
  
  SkillState({
    required this.skillRegistry,
    this.enabledSkills = const [],
    this.customSkills = const [],
  });
}

// Prompt 模式服务
//
// 控制注入到 LLM 的系统提示内容

/// Prompt 模式
enum PromptMode {
  /// 完整模式（主代理）
  full,
  
  /// 精简模式（子代理）
  minimal,
  
  /// 无模式（仅基本身份）
  none,
}

/// Prompt 配置
class PromptConfig {
  final PromptMode mode;
  final int maxBootstrapChars;
  final int maxSkillsList;
  final bool includeMemory;
  final bool includeHeartbeat;
  final bool includeTools;
  final bool includeSkills;

  const PromptConfig({
    this.mode = PromptMode.full,
    this.maxBootstrapChars = 150000,
    this.maxSkillsList = 20,
    this.includeMemory = true,
    this.includeHeartbeat = true,
    this.includeTools = true,
    this.includeSkills = true,
  });

  /// 完整模式配置
  static const PromptConfig full = PromptConfig();

  /// 精简模式配置（子代理用）
  static const PromptConfig minimal = PromptConfig(
    mode: PromptMode.minimal,
    maxBootstrapChars: 50000,
    maxSkillsList: 5,
    includeMemory: false,
    includeHeartbeat: false,
    includeSkills: false,
  );

  /// 无模式配置
  static const PromptConfig none = PromptConfig(
    mode: PromptMode.none,
    maxBootstrapChars: 0,
    maxSkillsList: 0,
    includeMemory: false,
    includeHeartbeat: false,
    includeTools: false,
    includeSkills: false,
  );
}

/// Prompt 构建器
class PromptBuilder {
  final PromptConfig config;
  final String identity;
  final String? soul;
  final String? user;

  PromptBuilder({
    required this.config,
    required this.identity,
    this.soul,
    this.user,
  });

  /// 构建系统提示
  String buildSystemPrompt({
    List<String>? skills,
    String? heartbeatPrompt,
    List<String>? tools,
    String? currentTime,
    String? additionalContext,
  }) {
    if (config.mode == PromptMode.none) {
      return _buildMinimalIdentity();
    }

    final buffer = StringBuffer();

    // 1. 身份
    buffer.writeln(_buildIdentitySection());
    buffer.writeln();

    // 2. 工具列表（如果启用）
    if (config.includeTools && tools != null && tools.isNotEmpty) {
      buffer.writeln(_buildToolsSection(tools));
      buffer.writeln();
    }

    // 3. 技能列表（如果启用）
    if (config.includeSkills && skills != null && skills.isNotEmpty) {
      buffer.writeln(_buildSkillsSection(skills));
      buffer.writeln();
    }

    // 4. 心跳提示（如果启用）
    if (config.includeHeartbeat && heartbeatPrompt != null) {
      buffer.writeln(_buildHeartbeatSection(heartbeatPrompt));
      buffer.writeln();
    }

    // 5. 当前时间（如果提供）
    if (currentTime != null) {
      buffer.writeln(_buildTimeSection(currentTime));
      buffer.writeln();
    }

    // 6. 附加上下文
    if (additionalContext != null) {
      buffer.writeln(additionalContext);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// 构建最小身份
  String _buildMinimalIdentity() {
    return '你是 $identity。';
  }

  /// 构建身份部分
  String _buildIdentitySection() {
    final buffer = StringBuffer();
    buffer.writeln('## 身份');
    buffer.writeln();
    buffer.writeln(identity);
    
    if (soul != null && soul!.isNotEmpty && config.mode == PromptMode.full) {
      buffer.writeln();
      buffer.writeln(soul);
    }
    
    if (user != null && user!.isNotEmpty && config.mode == PromptMode.full) {
      buffer.writeln();
      buffer.writeln('### 用户信息');
      buffer.writeln(user);
    }
    
    return buffer.toString();
  }

  /// 构建工具部分
  String _buildToolsSection(List<String> tools) {
    final buffer = StringBuffer();
    buffer.writeln('## 工具');
    buffer.writeln();
    buffer.writeln('你可以使用以下工具：');
    
    for (final tool in tools) {
      buffer.writeln('- $tool');
    }
    
    return buffer.toString();
  }

  /// 构建技能部分
  String _buildSkillsSection(List<String> skills) {
    final limitedSkills = skills.take(config.maxSkillsList).toList();
    
    final buffer = StringBuffer();
    buffer.writeln('## 技能');
    buffer.writeln();
    buffer.writeln('可用技能：');
    
    for (final skill in limitedSkills) {
      buffer.writeln('- $skill');
    }
    
    if (skills.length > config.maxSkillsList) {
      buffer.writeln('- ... 以及其他 ${skills.length - config.maxSkillsList} 个技能');
    }
    
    return buffer.toString();
  }

  /// 构建心跳部分
  String _buildHeartbeatSection(String heartbeatPrompt) {
    final buffer = StringBuffer();
    buffer.writeln('## 心跳');
    buffer.writeln();
    buffer.writeln(heartbeatPrompt);
    
    return buffer.toString();
  }

  /// 构建时间部分
  String _buildTimeSection(String currentTime) {
    final buffer = StringBuffer();
    buffer.writeln('## 当前时间');
    buffer.writeln();
    buffer.writeln(currentTime);
    
    return buffer.toString();
  }
}

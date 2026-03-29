// Skill 参数提取器
//
// 从 SKILL.md 中自动提取可测试的参数

/// 技能参数定义
class SkillParam {
  final String name;
  final String label;
  final String? description;
  final String type; // text, number, select, boolean
  final String? defaultValue;
  final List<String>? options; // for select type
  final bool required;
  final String? placeholder;

  SkillParam({
    required this.name,
    required this.label,
    this.description,
    this.type = 'text',
    this.defaultValue,
    this.options,
    this.required = true,
    this.placeholder,
  });

  factory SkillParam.fromJson(Map<String, dynamic> json) {
    return SkillParam(
      name: json['name'] ?? '',
      label: json['label'] ?? json['name'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'text',
      defaultValue: json['defaultValue']?.toString(),
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      required: json['required'] ?? true,
      placeholder: json['placeholder'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'description': description,
    'type': type,
    'defaultValue': defaultValue,
    'options': options,
    'required': required,
    'placeholder': placeholder,
  };
}

/// 参数提取结果
class ExtractedParams {
  final List<SkillParam> params;
  final String? sampleUrl;
  final Map<String, String> detectedVariables;

  ExtractedParams({
    required this.params,
    this.sampleUrl,
    this.detectedVariables = const {},
  });
}

/// Skill 参数提取器
class SkillParamExtractor {
  /// 从 SKILL.md 内容提取参数
  static ExtractedParams extract(String markdown) {
    final params = <SkillParam>[];
    String? sampleUrl;
    final detectedVariables = <String, String>{};

    // 1. 查找明确的参数定义部分
    final paramSection = _findParamSection(markdown);
    if (paramSection != null) {
      params.addAll(_parseParamSection(paramSection));
    }

    // 2. 从 HTTP 代码块提取参数
    final httpBlocks = _extractHttpBlocks(markdown);
    for (final block in httpBlocks) {
      final urlParams = _extractUrlParams(block);
      for (final param in urlParams) {
        if (!params.any((p) => p.name == param.name)) {
          params.add(param);
        }
      }
      
      // 记录示例 URL
      if (sampleUrl == null) {
        final urlMatch = RegExp(r'GET\s+(https?://[^\s]+)').firstMatch(block);
        if (urlMatch != null) {
          sampleUrl = urlMatch.group(1);
        }
      }
    }

    // 3. 从代码块中的 {variable} 提取参数
    final variables = _extractVariables(markdown);
    for (final entry in variables.entries) {
      detectedVariables[entry.key] = entry.value;
      
      if (!params.any((p) => p.name == entry.key)) {
        params.add(SkillParam(
          name: entry.key,
          label: _formatLabel(entry.key),
          placeholder: entry.value.isNotEmpty ? entry.value : null,
          required: true,
        ));
      }
    }

    // 4. 从 frontmatter 的 openclaw.params 提取
    final frontmatterParams = _extractFromFrontmatter(markdown);
    for (final param in frontmatterParams) {
      final existingIndex = params.indexWhere((p) => p.name == param.name);
      if (existingIndex >= 0) {
        // 合并信息
        params[existingIndex] = SkillParam(
          name: param.name,
          label: param.label.isNotEmpty ? param.label : params[existingIndex].label,
          description: param.description ?? params[existingIndex].description,
          type: param.type != 'text' ? param.type : params[existingIndex].type,
          defaultValue: param.defaultValue ?? params[existingIndex].defaultValue,
          options: param.options ?? params[existingIndex].options,
          required: param.required,
          placeholder: param.placeholder ?? params[existingIndex].placeholder,
        );
      } else {
        params.add(param);
      }
    }

    return ExtractedParams(
      params: params,
      sampleUrl: sampleUrl,
      detectedVariables: detectedVariables,
    );
  }

  /// 查找参数定义部分
  static String? _findParamSection(String markdown) {
    // 查找 ## Parameters 或 ## 参数 部分
    final patterns = [
      RegExp(r'##\s*Parameters[\s\S]*?(?=##|$)', caseSensitive: false),
      RegExp(r'##\s*参数[\s\S]*?(?=##|$)', caseSensitive: false),
      RegExp(r'##\s*Arguments[\s\S]*?(?=##|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(markdown);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  /// 解析参数部分
  static List<SkillParam> _parseParamSection(String section) {
    final params = <SkillParam>[];

    // 格式1: Markdown 列表
    // - `name`: Description
    // - `name` (type): Description
    final listPattern = RegExp(r'-\s*`(\w+)`\s*(?:\((\w+)\))?\s*:\s*(.+)');
    for (final match in listPattern.allMatches(section)) {
      params.add(SkillParam(
        name: match.group(1)!,
        label: _formatLabel(match.group(1)!),
        description: match.group(3)?.trim(),
        type: match.group(2) ?? 'text',
      ));
    }

    // 格式2: 表格
    // | Name | Type | Description |
    // |------|------|-------------|
    // | name | text | Description |
    final tablePattern = RegExp(r'\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*([^|]+)\s*\|');
    for (final match in tablePattern.allMatches(section)) {
      final name = match.group(1)!;
      // 跳过表头
      if (name.toLowerCase() == 'name' || name.toLowerCase() == '参数') continue;
      
      params.add(SkillParam(
        name: name,
        label: _formatLabel(name),
        description: match.group(3)?.trim(),
        type: match.group(2) ?? 'text',
      ));
    }

    return params;
  }

  /// 提取 HTTP 代码块
  static List<String> _extractHttpBlocks(String markdown) {
    final blocks = <String>[];
    final pattern = RegExp(r'```(?:http|bash|sh|shell)?\s*\n([\s\S]*?)\n```');
    
    for (final match in pattern.allMatches(markdown)) {
      final code = match.group(1)!;
      if (code.contains('http://') || code.contains('https://') || 
          code.contains('curl') || code.contains('GET') || code.contains('POST')) {
        blocks.add(code);
      }
    }
    
    return blocks;
  }

  /// 从 HTTP 代码块提取 URL 参数
  static List<SkillParam> _extractUrlParams(String code) {
    final params = <SkillParam>[];

    // 提取 URL 中的路径参数 {param} 和查询参数 ?param=
    
    // 路径参数 {param}
    final pathParams = RegExp(r'\{(\w+)\}');
    for (final match in pathParams.allMatches(code)) {
      params.add(SkillParam(
        name: match.group(1)!,
        label: _formatLabel(match.group(1)!),
        type: 'text',
      ));
    }

    // 查询参数 ?param= 或 &param=
    final queryParams = RegExp(r'[?&](\w+)=(?:\{([^}]+)\}|([^&\s]*))');
    for (final match in queryParams.allMatches(code)) {
      final name = match.group(1)!;
      final placeholder = match.group(2) ?? match.group(3);
      
      params.add(SkillParam(
        name: name,
        label: _formatLabel(name),
        placeholder: placeholder,
        type: _guessParamType(name),
      ));
    }

    return params;
  }

  /// 从整个 Markdown 提取变量
  static Map<String, String> _extractVariables(String markdown) {
    final variables = <String, String>{};
    
    // 匹配 {variable_name} 或 {variable_name:default}
    final pattern = RegExp(r'\{(\w+)(?::([^}]*))?\}');
    
    for (final match in pattern.allMatches(markdown)) {
      final name = match.group(1)!;
      final defaultValue = match.group(2) ?? '';
      variables[name] = defaultValue;
    }
    
    return variables;
  }

  /// 从 frontmatter 提取参数定义
  static List<SkillParam> _extractFromFrontmatter(String markdown) {
    final params = <SkillParam>[];

    // 解析 frontmatter
    final frontmatterMatch = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n').firstMatch(markdown);
    if (frontmatterMatch == null) return params;

    final frontmatter = frontmatterMatch.group(1)!;

    // 查找 openclaw.params
    final paramsMatch = RegExp(r'params:\s*\n((?:\s+-\s+.+\n?)+)').firstMatch(frontmatter);
    if (paramsMatch != null) {
      final paramsText = paramsMatch.group(1)!;
      final paramLines = RegExp(r'-\s+(.+)\n?').allMatches(paramsText);
      
      for (final lineMatch in paramLines) {
        final line = lineMatch.group(1)!;
        // 解析参数行
        // 格式: name (type, required): description
        // 或: name: description
        final paramPattern = RegExp(r'(\w+)\s*(?:\((\w+)(?:,\s*(required|optional))?\))?\s*:\s*(.+)?');
        final paramMatch = paramPattern.firstMatch(line);
        
        if (paramMatch != null) {
          params.add(SkillParam(
            name: paramMatch.group(1)!,
            label: _formatLabel(paramMatch.group(1)!),
            description: paramMatch.group(4)?.trim(),
            type: paramMatch.group(2) ?? 'text',
            required: paramMatch.group(3) != 'optional',
          ));
        }
      }
    }

    return params;
  }

  /// 格式化标签
  static String _formatLabel(String name) {
    // 将 snake_case 或 camelCase 转换为可读的标签
    final words = name
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    
    // 首字母大写
    return words.map((w) => 
        w[0].toUpperCase() + w.substring(1).toLowerCase()
    ).join(' ');
  }

  /// 根据参数名猜测类型
  static String _guessParamType(String name) {
    final lower = name.toLowerCase();
    
    if (lower.contains('count') || lower.contains('num') || 
        lower.contains('size') || lower.contains('limit') ||
        lower.contains('amount') || lower.contains('age')) {
      return 'number';
    }
    
    if (lower == 'enabled' || lower == 'active' || 
        lower.contains('is_') || lower.contains('has_')) {
      return 'boolean';
    }
    
    if (lower == 'format' || lower == 'type' || lower == 'sort') {
      return 'select';
    }
    
    return 'text';
  }

  /// 生成测试参数的默认值
  static Map<String, dynamic> generateTestValues(List<SkillParam> params) {
    final values = <String, dynamic>{};
    
    for (final param in params) {
      if (param.defaultValue != null) {
        values[param.name] = param.defaultValue;
        continue;
      }
      
      switch (param.type) {
        case 'number':
          values[param.name] = 10;
          break;
        case 'boolean':
          values[param.name] = true;
          break;
        case 'select':
          values[param.name] = param.options?.firstOrNull ?? 'default';
          break;
        default:
          // 根据 name 生成合理的默认值
          values[param.name] = _generateDefaultValue(param.name);
      }
    }
    
    return values;
  }

  /// 根据参数名生成默认值
  static String _generateDefaultValue(String name) {
    final lower = name.toLowerCase();
    
    if (lower.contains('city') || lower.contains('location')) {
      return 'Beijing';
    }
    if (lower.contains('country')) {
      return 'CN';
    }
    if (lower.contains('lang') || lower.contains('language')) {
      return 'en';
    }
    if (lower.contains('ip')) {
      return '8.8.8.8';
    }
    if (lower.contains('url') || lower.contains('link')) {
      return 'https://example.com';
    }
    if (lower.contains('email')) {
      return 'test@example.com';
    }
    if (lower.contains('name') && !lower.contains('user')) {
      return 'Test';
    }
    if (lower.contains('query') || lower.contains('q') || lower.contains('search')) {
      return 'test query';
    }
    if (lower.contains('text') || lower.contains('message') || lower.contains('content')) {
      return 'Hello, world!';
    }
    if (lower.contains('from')) {
      return 'USD';
    }
    if (lower.contains('to') && lower.contains('currency')) {
      return 'CNY';
    }
    
    return 'test';
  }
}

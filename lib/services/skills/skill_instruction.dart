// Skill 指令类型
//
// 定义各种可执行的指令类型

/// 指令基类
abstract class SkillInstruction {
  final String language;
  final String code;
  final Map<String, dynamic> metadata;

  SkillInstruction({
    required this.language,
    required this.code,
    this.metadata = const {},
  });

  /// 从代码块解析指令
  factory SkillInstruction.fromCodeBlock(String language, String code) {
    final lang = language.toLowerCase();
    
    // 检查是否是 use: 指令
    if (code.trim().startsWith('use:')) {
      return UseInstruction.fromCode(code);
    }
    
    if (lang == 'bash' || lang == 'sh' || lang == 'shell') {
      return BashInstruction(code: code);
    } else if (lang == 'http' || lang == 'curl') {
      return HttpInstruction.fromCode(code);
    } else if (lang == 'dart') {
      return DartInstruction(code: code);
    } else if (lang == 'yaml' || lang == 'json') {
      return ConfigInstruction(code: code, language: language);
    }
    return GenericInstruction(language: language, code: code);
  }

  @override
  String toString() => 'SkillInstruction($language)';
}

/// Bash 指令
class BashInstruction extends SkillInstruction {
  BashInstruction({required String code})
      : super(language: 'bash', code: code);
}

/// HTTP 指令
class HttpInstruction extends SkillInstruction {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String? body;

  HttpInstruction({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
  }) : super(language: 'http', code: '');

  /// 从 curl 命令或 HTTP 代码解析
  factory HttpInstruction.fromCode(String code) {
    String method = 'GET';
    String url = '';
    Map<String, String> headers = {};
    String? body;

    // 解析 URL - 支持 GET/POST 格式
    // Pattern: optional HTTP method or curl, optional quotes, URL
    final urlPattern = RegExp(
      r'(GET|POST|PUT|DELETE|curl\s+)?["\x27]?(https?:\/\/[^\s"\x27]+)["\x27]?'
    );
    final urlMatch = urlPattern.firstMatch(code);
    if (urlMatch != null) {
      url = urlMatch.group(2) ?? '';
    }

    // 解析 method
    if (code.contains('-X POST') || code.contains('--request POST') || code.contains('POST ')) {
      method = 'POST';
    } else if (code.contains('-X PUT') || code.contains('PUT ')) {
      method = 'PUT';
    } else if (code.contains('-X DELETE') || code.contains('DELETE ')) {
      method = 'DELETE';
    }

    // 解析 headers: -H "Name: Value"
    final headerPattern = RegExp(r'-H\s+["\x27]([^:]+):\s*([^"\x27]+)["\x27]');
    for (final match in headerPattern.allMatches(code)) {
      headers[match.group(1) ?? ''] = match.group(2) ?? '';
    }

    // 解析 body: -d "data"
    final bodyPattern = RegExp(r'-d\s+["\x27]([^"\x27]+)["\x27]');
    final bodyMatch = bodyPattern.firstMatch(code);
    if (bodyMatch != null) {
      body = bodyMatch.group(1);
      if (method == 'GET') method = 'POST';
    }

    return HttpInstruction(
      method: method,
      url: url,
      headers: headers,
      body: body,
    );
  }
}

/// Dart 指令（移动端特有）
class DartInstruction extends SkillInstruction {
  DartInstruction({required String code})
      : super(language: 'dart', code: code);
}

/// 配置指令
class ConfigInstruction extends SkillInstruction {
  ConfigInstruction({required String code, required String language})
      : super(language: language, code: code);
}

/// 通用指令
class GenericInstruction extends SkillInstruction {
  GenericInstruction({required String language, required String code})
      : super(language: language, code: code);
}

/// Use 指令（调用基础能力）
class UseInstruction extends SkillInstruction {
  final String capability;  // 能力名称，如 'location', 'tts', 'http'
  final Map<String, dynamic> params;

  UseInstruction({
    required this.capability,
    this.params = const {},
  }) : super(language: 'use', code: '');

  /// 从代码解析
  /// 格式: use: capability_name
  /// 或: use: capability_name(param1=value1, param2=value2)
  factory UseInstruction.fromCode(String code) {
    final trimmed = code.trim();
    
    // 解析格式: use: capability 或 use: capability(params)
    final match = RegExp(r'use:\s*(\w+)(?:\((.+)\))?').firstMatch(trimmed);
    
    if (match == null) {
      return UseInstruction(capability: 'unknown');
    }
    
    final capability = match.group(1) ?? 'unknown';
    final paramsStr = match.group(2);
    
    final params = <String, dynamic>{};
    if (paramsStr != null) {
      // 解析参数: key=value, key="value with spaces"
      final paramPattern = RegExp(r'(\w+)=["\x27]?([^,)\x27"]+)["\x27]?');
      for (final paramMatch in paramPattern.allMatches(paramsStr)) {
        final key = paramMatch.group(1);
        final value = paramMatch.group(2);
        if (key != null && value != null) {
          params[key] = value;
        }
      }
    }
    
    return UseInstruction(capability: capability, params: params);
  }
}


// Skill 系统
//
// 完全兼容 OpenClaw 的 skill 格式

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Skill 异常
class SkillException implements Exception {
  final String message;
  SkillException(this.message);

  @override
  String toString() => 'SkillException: $message';
}

/// Skill 元数据
class SkillMetadata {
  final String name;
  final String description;
  final String? homepage;
  final Map<String, dynamic>? openclaw;

  SkillMetadata({
    required this.name,
    required this.description,
    this.homepage,
    this.openclaw,
  });

  factory SkillMetadata.fromYaml(Map<String, dynamic> yaml) {
    return SkillMetadata(
      name: yaml['name'] ?? 'unknown',
      description: yaml['description'] ?? '',
      homepage: yaml['homepage'],
      openclaw: yaml['metadata']?['openclaw'] ?? yaml['openclaw'],
    );
  }
}

/// Skill 定义
class Skill {
  final String id;
  final String? path;
  final SkillMetadata metadata;
  final String body;
  final Map<String, String> scripts;
  final Map<String, String> references;

  Skill({
    required this.id,
    this.path,
    required this.metadata,
    required this.body,
    this.scripts = const {},
    this.references = const {},
  });

  /// 检查是否支持当前平台
  bool isSupported() {
    final requires = metadata.openclaw?['requires'];
    if (requires == null) return true;

    // 移动端不支持 bins 要求
    final bins = requires['bins'] as List?;
    if (bins != null && bins.isNotEmpty) {
      return false;
    }

    return true;
  }
}

/// Skill 注册表
class SkillRegistry {
  final Map<String, Skill> _skills = {};
  bool _loaded = false;

  void register(Skill skill) => _skills[skill.id] = skill;
  void unregister(String id) => _skills.remove(id);
  Skill? get(String id) => _skills[id];
  List<Skill> getAllSkills() => _skills.values.toList();
  List<Skill> get available => _skills.values.toList();
  bool get isLoaded => _loaded;
  void markLoaded() => _loaded = true;
  void clear() { _skills.clear(); _loaded = false; }
  int get length => _skills.length;

  /// 匹配用户输入
  List<Skill> match(String input) {
    final lowerInput = input.toLowerCase();
    return available.where((skill) {
      final desc = skill.metadata.description.toLowerCase();
      final name = skill.metadata.name.toLowerCase();
      return desc.contains(lowerInput) || lowerInput.contains(name);
    }).toList();
  }

  /// 检查消息是否匹配 Skill
  static bool matchesSkill(String message, Skill skill) {
    final lowerMessage = message.toLowerCase();
    final desc = skill.metadata.description.toLowerCase();
    final name = skill.metadata.name.toLowerCase();

    // 名称匹配
    if (lowerMessage.contains(name)) return true;

    // 从描述中提取关键词匹配
    final keywords = <String>[];
    if (desc.contains('weather') || desc.contains('天气')) {
      keywords.addAll(['天气', 'weather', '气温', '温度']);
    }
    if (desc.contains('time') || desc.contains('时间')) {
      keywords.addAll(['几点', '时间', 'time', '星期几', '日期']);
    }
    if (desc.contains('translat') || desc.contains('翻译')) {
      keywords.addAll(['翻译', 'translate']);
    }
    if (desc.contains('search') || desc.contains('搜索')) {
      keywords.addAll(['搜索', 'search', '查找']);
    }
    if (desc.contains('calculat') || desc.contains('计算')) {
      keywords.addAll(['计算', 'calculate', '等于']);
      if (RegExp(r'\d+\s*[\+\-\*\/]\s*\d+').hasMatch(message)) return true;
    }
    if (desc.contains('random') || desc.contains('随机')) {
      keywords.addAll(['随机', 'random', 'roll']);
    }
    if (desc.contains('remind') || desc.contains('提醒')) {
      keywords.addAll(['提醒', 'reminder']);
    }

    for (final keyword in keywords) {
      if (lowerMessage.contains(keyword)) return true;
    }

    return false;
  }
  
  /// 从 Skill 的 body 中提取参数占位符
  /// 返回 Map<参数名, 参数说明>
  static Map<String, String> extractParamPlaceholders(Skill skill) {
    final params = <String, String>{};
    final body = skill.body;
    
    // 匹配 {param_name} 格式的占位符
    final placeholderRegex = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final matches = placeholderRegex.allMatches(body);
    
    // 参数名到说明的映射
    final paramDescriptions = {
      'location': '位置/城市',
      'city': '城市',
      'country': '国家',
      'lat': '纬度',
      'lon': '经度',
      'lng': '经度',
      'query': '搜索关键词',
      'q': '搜索关键词',
      'text': '文本内容',
      'content': '内容',
      'message': '消息',
      'url': 'URL 地址',
      'link': '链接',
      'api_key': 'API 密钥',
      'apikey': 'API 密钥',
      'key': '密钥',
      'id': 'ID',
      'user_id': '用户 ID',
      'from': '来源货币',
      'to': '目标货币',
      'amount': '数量',
      'number': '数字',
      'count': '数量',
      'limit': '限制数量',
      'page': '页码',
      'size': '大小',
      'width': '宽度',
      'height': '高度',
      'format': '格式',
      'lang': '语言',
      'language': '语言',
      'ip': 'IP 地址',
      'data': '数据内容',
      'name': '名称',
      'title': '标题',
      'description': '描述',
    };
    
    for (final match in matches) {
      final paramName = match.group(1)!;
      if (!params.containsKey(paramName)) {
        params[paramName] = paramDescriptions[paramName] ?? paramName;
      }
    }
    
    return params;
  }

  /// 从消息中提取 Skill 参数
  static Map<String, dynamic> extractParams(String message, Skill skill) {
    final params = <String, dynamic>{};
    final name = skill.metadata.name.toLowerCase();

    // 天气 Skill - 提取城市
    if (name == 'weather') {
      final cities = [
        '北京', '上海', '广州', '深圳', '杭州', '成都', '武汉', '西安',
        '南京', '天津', '重庆', '苏州', '郑州', '长沙', '沈阳', '青岛',
        '南宁', '昆明', '贵阳', '海口', '兰州', 'Beijing', 'Shanghai',
        'Guangzhou', 'Shenzhen', 'Hangzhou', 'Chengdu',
      ];
      for (final city in cities) {
        if (message.contains(city)) {
          params['location'] = city;
          break;
        }
      }
      if (params['location'] == null) {
        final match = RegExp(r'([^\s]+)(?:市|的天气)').firstMatch(message);
        if (match != null) params['location'] = match.group(1);
      }
    }

    // 计算器 Skill - 提取表达式
    if (name == 'calculator') {
      final match = RegExp(r'[\d\+\-\*\/\(\)\.]+').firstMatch(message);
      if (match != null) params['expression'] = match.group(0)!;
    }

    // 随机数 Skill - 提取范围
    if (name == 'random') {
      final match = RegExp(r'(\d+)-(\d+)').firstMatch(message);
      if (match != null) {
        params['min'] = int.parse(match.group(1)!);
        params['max'] = int.parse(match.group(2)!);
      }
    }

    return params;
  }
}

/// Skill 解析器
class SkillParser {
  /// 解析 SKILL.md 文件
  static (Map<String, dynamic>, String) parseMarkdown(String content) {
    final lines = content.split('\n');
    
    debugPrint('[SkillParser] Parsing content, ${lines.length} lines');
    debugPrint('[SkillParser] First line: ${lines.isNotEmpty ? lines.first : '(empty)'}');
    
    if (lines.isEmpty || lines.first.trim() != '---') {
      debugPrint('[SkillParser] No frontmatter found');
      return ({}, content);
    }

    int endIndex = 1;
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        endIndex = i;
        break;
      }
    }

    final frontmatter = lines.sublist(1, endIndex).join('\n');
    final body = lines.sublist(endIndex + 1).join('\n');
    
    debugPrint('[SkillParser] Frontmatter: $frontmatter');
    debugPrint('[SkillParser] Body length: ${body.length}');
    
    final parsed = _parseYaml(frontmatter);
    debugPrint('[SkillParser] Parsed YAML: $parsed');
    
    return (parsed, body);
  }

  static Map<String, dynamic> _parseYaml(String yaml) {
    final result = <String, dynamic>{};
    for (final line in yaml.split('\n')) {
      if (line.trim().isEmpty) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        var value = line.substring(colonIndex + 1).trim();
        
        // 移除引号
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        
        // 尝试解析 JSON
        if (value.startsWith('{') || value.startsWith('[')) {
          try {
            result[key] = json.decode(value);
          } catch (_) {
            result[key] = value;
          }
        } else {
          result[key] = value;
        }
      }
    }
    return result;
  }
}

/// Skill 加载器
class SkillLoader {
  /// 从 assets 目录加载所有 Skills
  Future<List<Skill>> loadFromAssets() async {
    final skills = <Skill>[];
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);
      
      debugPrint('[SkillLoader] Assets manifest loaded, ${manifestMap.length} items');
      
      // 列出所有 assets
      final allAssets = manifestMap.keys.toList();
      debugPrint('[SkillLoader] All assets: $allAssets');
      
      final skillFiles = allAssets
          .where((path) => path.contains('SKILL.md'))
          .toList();

      debugPrint('[SkillLoader] Found ${skillFiles.length} SKILL.md files: $skillFiles');

      for (final skillPath in skillFiles) {
        try {
          debugPrint('[SkillLoader] Loading: $skillPath');
          final content = await rootBundle.loadString(skillPath);
          debugPrint('[SkillLoader] Content length: ${content.length}');
          debugPrint('[SkillLoader] Content preview: ${content.substring(0, content.length > 100 ? 100 : content.length)}');
          
          final (frontmatter, body) = SkillParser.parseMarkdown(content);
          debugPrint('[SkillLoader] Parsed frontmatter: $frontmatter');
          
          if (frontmatter.isNotEmpty && frontmatter['name'] != null) {
            final metadata = SkillMetadata.fromYaml(frontmatter);
            skills.add(Skill(
              id: metadata.name,
              path: skillPath.replaceAll('/SKILL.md', ''),
              metadata: metadata,
              body: body,
            ));
            debugPrint('[SkillLoader] ✓ Loaded skill: ${metadata.name}');
          } else {
            debugPrint('[SkillLoader] ✗ Invalid frontmatter in: $skillPath');
            debugPrint('[SkillLoader] frontmatter: $frontmatter');
          }
        } catch (e, stack) {
          debugPrint('[SkillLoader] ✗ Error loading $skillPath: $e');
          debugPrint('[SkillLoader] Stack: $stack');
        }
      }
    } catch (e, stack) {
      debugPrint('[SkillLoader] ✗ Error reading manifest: $e');
      debugPrint('[SkillLoader] Stack: $stack');
    }
    
    debugPrint('[SkillLoader] Total skills loaded: ${skills.length}');
    return skills;
  }
  
  /// 从 URL 加载 Skill
  Future<Skill?> loadFromUrl(String url) async {
    try {
      debugPrint('[SkillLoader] Loading from URL: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        debugPrint('[SkillLoader] HTTP error: ${response.statusCode}');
        return null;
      }
      
      final content = response.body;
      return parseSkillContent(content, source: url);
    } catch (e) {
      debugPrint('[SkillLoader] Error loading from URL: $e');
      return null;
    }
  }
  
  /// 从字符串内容解析 Skill
  Skill? parseSkillContent(String content, {String? source}) {
    try {
      final (frontmatter, body) = SkillParser.parseMarkdown(content);
      
      if (frontmatter.isEmpty || frontmatter['name'] == null) {
        debugPrint('[SkillLoader] Invalid SKILL.md format');
        return null;
      }
      
      final metadata = SkillMetadata.fromYaml(frontmatter);
      return Skill(
        id: metadata.name,
        path: source,
        metadata: metadata,
        body: body,
      );
    } catch (e) {
      debugPrint('[SkillLoader] Error parsing skill: $e');
      return null;
    }
  }
}

/// Skill 执行器
class SkillExecutor {
  final http.Client _client = http.Client();

  /// 执行 skill
  Future<String> execute(Skill skill, Map<String, dynamic> params) async {
    if (!skill.isSupported()) {
      return '⚠️ 当前平台不支持此 Skill';
    }
    
    debugPrint('[SkillExecutor] ========== 执行 Skill ==========');
    debugPrint('[SkillExecutor] Skill ID: ${skill.id}');
    debugPrint('[SkillExecutor] Skill Name: ${skill.metadata.name}');
    debugPrint('[SkillExecutor] Body length: ${skill.body.length}');
    debugPrint('[SkillExecutor] Body: ${skill.body}');

    // 解析 body 中的指令
    final instructions = _parseInstructions(skill.body);
    
    debugPrint('[SkillExecutor] Parsed ${instructions.length} instructions');
    
    for (final instruction in instructions) {
      debugPrint('[SkillExecutor] Executing: ${instruction.type} - ${instruction.content.substring(0, instruction.content.length > 50 ? 50 : instruction.content.length)}');
      
      switch (instruction.type) {
        case _InstructionType.http:
          return await _executeHttp(instruction, params);
        case _InstructionType.builtin:
          return _executeBuiltin(instruction, params);
        case _InstructionType.curl:
          return await _executeCurl(instruction, params);
      }
    }

    debugPrint('[SkillExecutor] ✗ 没有找到可执行的指令');
    return 'Skill "${skill.metadata.name}" 没有可执行的指令';
  }

  List<_Instruction> _parseInstructions(String body) {
    final instructions = <_Instruction>[];

    // 匹配 ```http 代码块
    final httpRegex = RegExp(r'```http\s*\n([\s\S]*?)\n```', multiLine: true);
    for (final match in httpRegex.allMatches(body)) {
      instructions.add(_Instruction(_InstructionType.http, match.group(1)!));
    }

    // 匹配 ```builtin 代码块
    final builtinRegex = RegExp(r'```builtin\s*\n([\s\S]*?)\n```', multiLine: true);
    for (final match in builtinRegex.allMatches(body)) {
      instructions.add(_Instruction(_InstructionType.builtin, match.group(1)!));
    }

    // 匹配 ```bash 代码块中的 curl 命令（OpenClaw 格式）
    final bashRegex = RegExp(r'```bash\s*\n([\s\S]*?)\n```', multiLine: true);
    for (final match in bashRegex.allMatches(body)) {
      final bashContent = match.group(1)!;
      // 提取 curl 命令
      final curlCommands = _extractCurlCommands(bashContent);
      for (final curlCmd in curlCommands) {
        instructions.add(_Instruction(_InstructionType.curl, curlCmd));
      }
    }

    // 匹配独立的 curl 命令（不在代码块中）
    final curlCommands = _extractCurlCommands(body);
    for (final curlCmd in curlCommands) {
      // 避免重复添加
      if (!instructions.any((i) => i.content == curlCmd)) {
        instructions.add(_Instruction(_InstructionType.curl, curlCmd));
      }
    }

    return instructions;
  }
  
  /// 从文本中提取 curl 命令
  List<String> _extractCurlCommands(String text) {
    final commands = <String>[];
    
    // 匹配 curl 命令（支持各种格式）
    // 格式1: curl "https://..."
    // 格式2: curl 'https://...'
    // 格式3: curl https://...
    final curlRegex = RegExp(
      r'''curl\s+(-s\s+)?["']?(https?://[^"'\s]+)["']?''',
      multiLine: true
    );
    
    for (final match in curlRegex.allMatches(text)) {
      commands.add(match.group(2)!);
    }
    
    return commands;
  }

  Future<String> _executeHttp(_Instruction instruction, Map<String, dynamic> params) async {
    try {
      String url = instruction.content.trim();
      if (url.startsWith('GET ')) url = url.substring(4).trim();
      
      // 替换参数
      params.forEach((key, value) {
        url = url.replaceAll('{$key}', value.toString());
      });

      final response = await _client.get(Uri.parse(url), headers: {
        'User-Agent': 'curl/7.64.1',
        'Accept-Charset': 'utf-8',
      });
      
      if (response.statusCode != 200) {
        return '请求失败: ${response.statusCode}';
      }
      
      // 通用编码处理：始终使用 bodyBytes + UTF-8 解码
      // response.body 默认用 Latin-1 解码，会导致 UTF-8 内容（如中文、emoji）乱码
      String body;
      try {
        body = utf8.decode(response.bodyBytes, allowMalformed: true);
      } catch (_) {
        body = response.body;
      }
      
      // 修复常见的双重 UTF-8 编码（Â°C → °C 等）
      body = _fixDoubleEncoding(body);
      
      return body.trim();
    } catch (e) {
      return 'HTTP 执行错误: $e';
    }
  }
  
  /// 修复双重 UTF-8 编码问题（通用方法）
  String _fixDoubleEncoding(String text) {
    return text
        .replaceAll('Â°C', '°C')
        .replaceAll('Â°F', '°F')
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€“', '–')
        .replaceAll('â€”', '—')
        .replaceAll('â€¦', '…')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã¼', 'ü')
        .replaceAll('Ã¶', 'ö')
        .replaceAll('Ã¤', 'ä');
  }
  
  /// 执行 curl 命令（转换为 HTTP 请求）
  Future<String> _executeCurl(_Instruction instruction, Map<String, dynamic> params) async {
    try {
      String url = instruction.content.trim();
      
      // 替换参数
      params.forEach((key, value) {
        url = url.replaceAll('{$key}', value.toString());
      });
      
      // 替换默认位置（如果参数中没有 location）
      if (!params.containsKey('location') && url.contains('{location}')) {
        url = url.replaceAll('{location}', 'Beijing');
      }

      debugPrint('[SkillExecutor] curl -> HTTP GET: $url');
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'curl/7.64.1'},
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        // 通用编码处理：使用 bodyBytes + UTF-8 解码（与 _executeHttp 一致）
        final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
        
        // 修复双重编码
        final fixed = _fixDoubleEncoding(body);
        
        // 智能格式化：检测 JSON 响应（通用，不仅限于天气）
        if (url.contains('format=j1') || url.contains('format=json')) {
          try {
            final json = jsonDecode(fixed);
            // 天气 API 特殊处理
            if (url.contains('wttr.in')) {
              return _formatWeatherJson(fixed);
            }
            // 其他 JSON API：返回格式化的 JSON
            return const JsonEncoder.withIndent('  ').convert(json);
          } catch (_) {
            // JSON 解析失败，返回原始文本
          }
        }
        
        return fixed;
      } else {
        return '请求失败: ${response.statusCode}';
      }
    } catch (e) {
      return 'curl 执行错误: $e';
    }
  }

  /// 格式化天气 JSON 为友好文字
  String _formatWeatherJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr);
      
      // 获取当前位置
      final area = json['nearest_area']?[0]?['areaName']?[0]?['value'] ?? '未知位置';
      final country = json['nearest_area']?[0]?['country']?[0]?['value'] ?? '';
      
      // 获取当前天气
      final current = json['current_condition']?[0];
      if (current == null) return '无法获取天气信息';
      
      final tempC = current['temp_C'] ?? '?';
      final tempF = current['temp_F'] ?? '?';
      final feelsLike = current['FeelsLikeC'] ?? '?';
      final humidity = current['humidity'] ?? '?';
      final weatherDesc = current['weatherDesc']?[0]?['value'] ?? '未知';
      final windSpeed = current['windspeedKmph'] ?? '?';
      final cloudcover = current['cloudcover'] ?? '?';
      
      // 获取未来天气预报（今天）
      final today = json['weather']?[0];
      String? forecast;
      if (today != null) {
        final maxTemp = today['maxtempC'] ?? '?';
        final minTemp = today['mintempC'] ?? '?';
        final avgTemp = today['avgtempC'] ?? '?';
        forecast = '\n\n📊 今日预报：最高 ${maxTemp}°C，最低 ${minTemp}°C，平均 ${avgTemp}°C';
      }
      
      // 构建友好输出
      final location = country.isNotEmpty ? '$area, $country' : area;
      
      return '''🌤️ $location 天气

🌡️ 当前温度：$tempC°C ($tempF°F)
🌡️ 体感温度：$feelsLike°C
☁️ 天气状况：$weatherDesc
💨 风速：$windSpeed km/h
💧 湿度：$humidity%
☁️ 云量：$cloudcover%${forecast ?? ''}''';
    } catch (e) {
      debugPrint('[SkillExecutor] 天气 JSON 解析失败: $e');
      // 解析失败时返回原始内容
      return jsonStr;
    }
  }

  String _executeBuiltin(_Instruction instruction, Map<String, dynamic> params) {
    final content = instruction.content.trim();
    
    if (content == 'time') {
      final now = DateTime.now();
      final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '当前时间: ${now.year}年${now.month}月${now.day}日 '
          '星期${weekdays[now.weekday - 1]} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
    }
    
    if (content == 'calculator') {
      final expr = params['expression'] as String?;
      if (expr == null || expr.isEmpty) return '请提供计算表达式';
      
      try {
        // 移除空格
        final cleanExpr = expr.replaceAll(' ', '');
        
        // 简单的表达式计算
        final result = _simpleEval(cleanExpr);
        
        if (result != null) {
          return '计算结果: $expr = $result';
        } else {
          return '表达式格式错误: $expr';
        }
      } catch (e) {
        return '计算错误: $e';
      }
    }

    if (content == 'random') {
      final min = params['min'] as int? ?? 1;
      final max = params['max'] as int? ?? 100;
      
      if (min >= max) return '范围错误: 最小值必须小于最大值';
      
      final random = DateTime.now().millisecondsSinceEpoch % (max - min + 1) + min;
      return '随机数 ($min-$max): $random';
    }

    return '未知内置指令: $content';
  }

  void dispose() => _client.close();

  /// 简单的表达式计算（支持加减乘除）
  double? _simpleEval(String expr) {
    try {
      // 使用正则匹配简单表达式：数字 运算符 数字
      final match = RegExp(r'^([\d.]+)\s*([\+\-\*/])\s*([\d.]+)$').firstMatch(expr);
      if (match != null) {
        final a = double.parse(match.group(1)!);
        final op = match.group(2)!;
        final b = double.parse(match.group(3)!);
        
        final result = switch (op) {
          '+' => a + b,
          '-' => a - b,
          '*' => a * b,
          '/' => b != 0 ? a / b : throw Exception('除零错误'),
          _ => throw Exception('未知运算符'),
        };
        return result;
      }
      
      // 尝试链式计算（如 100*25/5）
      // 从左到右计算
      final tokens = RegExp(r'[\d.]+|[\+\-\*/]').allMatches(expr).map((m) => m.group(0)!).toList();
      if (tokens.isEmpty || tokens.length % 2 == 0) return null;
      
      double result = double.parse(tokens[0]);
      for (int i = 1; i < tokens.length; i += 2) {
        final op = tokens[i];
        final b = double.parse(tokens[i + 1]);
        
        result = switch (op) {
          '+' => result + b,
          '-' => result - b,
          '*' => result * b,
          '/' => b != 0 ? result / b : throw Exception('除零错误'),
          _ => throw Exception('未知运算符'),
        };
      }
      
      return result;
    } catch (e) {
      debugPrint('[Calculator] 表达式计算失败: $e');
      return null;
    }
  }
}

enum _InstructionType { http, builtin, curl }

class _Instruction {
  final _InstructionType type;
  final String content;
  _Instruction(this.type, this.content);
}

/// Skill 管理器（单例）
class SkillManager {
  static final SkillManager _instance = SkillManager._internal();
  factory SkillManager() => _instance;
  SkillManager._internal();

  final SkillRegistry _registry = SkillRegistry();
  final SkillLoader _loader = SkillLoader();
  
  // 用户安装的技能（存储在 SharedPreferences）
  final List<Skill> _userSkills = [];
  
  // 存储键
  static const String _storageKey = 'user_installed_skills';

  SkillRegistry get registry => _registry;
  List<Skill> get availableSkills => _registry.available;
  List<Skill> get userSkills => List.unmodifiable(_userSkills);

  /// 初始化：加载所有 Skills
  Future<void> initialize() async {
    debugPrint('[SkillManager] initialize() called, isLoaded=${_registry.isLoaded}');
    
    if (_registry.isLoaded) {
      debugPrint('[SkillManager] Already loaded, skipping');
      return;
    }

    // 1. 从 assets 加载内置技能
    debugPrint('[SkillManager] Loading skills from assets...');
    final assetSkills = await _loader.loadFromAssets();
    debugPrint('[SkillManager] Loaded ${assetSkills.length} skills from assets');
    
    for (final skill in assetSkills) {
      _registry.register(skill);
      debugPrint('[SkillManager] Registered: ${skill.id}');
    }
    
    // 2. 从本地存储加载用户安装的技能
    await _loadUserSkills();
    
    _registry.markLoaded();
    debugPrint('[SkillManager] Total skills in registry: ${_registry.available.length}');
  }
  
  /// 从本地存储加载用户安装的技能
  Future<void> _loadUserSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = prefs.getString(_storageKey);
      
      if (skillsJson != null) {
        final List<dynamic> skillsList = json.decode(skillsJson);
        
        for (final skillJson in skillsList) {
          try {
            final skill = _skillFromJson(skillJson as Map<String, dynamic>);
            if (skill != null) {
              _userSkills.add(skill);
              _registry.register(skill);
              debugPrint('[SkillManager] Loaded user skill: ${skill.id}');
            }
          } catch (e) {
            debugPrint('[SkillManager] Error loading user skill: $e');
          }
        }
        
        debugPrint('[SkillManager] Loaded ${_userSkills.length} user skills');
      }
    } catch (e) {
      debugPrint('[SkillManager] Error loading user skills: $e');
    }
  }
  
  /// 保存用户安装的技能到本地存储
  Future<void> _saveUserSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skillsJson = json.encode(_userSkills.map((s) => _skillToJson(s)).toList());
      await prefs.setString(_storageKey, skillsJson);
      debugPrint('[SkillManager] Saved ${_userSkills.length} user skills');
    } catch (e) {
      debugPrint('[SkillManager] Error saving user skills: $e');
    }
  }
  
  /// 从 JSON 创建 Skill
  Skill? _skillFromJson(Map<String, dynamic> json) {
    try {
      return Skill(
        id: json['id'] as String,
        path: json['path'] as String?,
        metadata: SkillMetadata(
          name: json['name'] as String,
          description: json['description'] as String,
          homepage: json['homepage'] as String?,
          openclaw: json['openclaw'] as Map<String, dynamic>?,
        ),
        body: json['body'] as String,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 将 Skill 转换为 JSON
  Map<String, dynamic> _skillToJson(Skill skill) {
    return {
      'id': skill.id,
      'path': skill.path,
      'name': skill.metadata.name,
      'description': skill.metadata.description,
      'homepage': skill.metadata.homepage,
      'openclaw': skill.metadata.openclaw,
      'body': skill.body,
    };
  }
  
  /// 从 URL 安装技能
  Future<bool> installFromUrl(String url) async {
    try {
      final skill = await _loader.loadFromUrl(url);
      if (skill == null) {
        debugPrint('[SkillManager] Failed to load skill from URL');
        return false;
      }
      
      return installSkill(skill);
    } catch (e) {
      debugPrint('[SkillManager] Error installing from URL: $e');
      return false;
    }
  }
  
  /// 从内容安装技能
  Future<bool> installFromContent(String content) async {
    try {
      final skill = _loader.parseSkillContent(content);
      if (skill == null) {
        debugPrint('[SkillManager] Failed to parse skill content');
        return false;
      }
      
      return installSkill(skill);
    } catch (e) {
      debugPrint('[SkillManager] Error installing from content: $e');
      return false;
    }
  }
  
  /// 安装技能
  bool installSkill(Skill skill) {
    // 检查是否已存在
    if (_registry.get(skill.id) != null) {
      debugPrint('[SkillManager] Skill already exists: ${skill.id}');
      // 更新
      _registry.unregister(skill.id);
      _userSkills.removeWhere((s) => s.id == skill.id);
    }
    
    _registry.register(skill);
    _userSkills.add(skill);
    _saveUserSkills();
    
    debugPrint('[SkillManager] ✓ Installed skill: ${skill.id}');
    return true;
  }
  
  /// 卸载技能
  Future<bool> uninstallSkill(String skillId) async {
    final skill = _registry.get(skillId);
    if (skill == null) {
      debugPrint('[SkillManager] Skill not found: $skillId');
      return false;
    }
    
    _registry.unregister(skillId);
    _userSkills.removeWhere((s) => s.id == skillId);
    await _saveUserSkills();
    
    debugPrint('[SkillManager] ✓ Uninstalled skill: $skillId');
    return true;
  }

  /// 匹配 Skill
  List<Skill> matchSkills(String message) {
    return _registry.available
        .where((skill) => SkillRegistry.matchesSkill(message, skill))
        .toList();
  }

  /// 执行 Skill
  Future<String> executeSkill(Skill skill, Map<String, dynamic> params) async {
    final executor = SkillExecutor();
    try {
      return await executor.execute(skill, params);
    } finally {
      executor.dispose();
    }
  }

  /// 技能存储路径（Learned Skills 的保存位置）
  String get skillsPath => 'learned';

  /// 保存从对话中学习的 Skill
  Future<bool> saveLearnedSkill(String skillId, String content) async {
    try {
      // 解析内容创建 Skill 对象
      final skill = _loader.parseSkillContent(content);
      if (skill != null) {
        return installSkill(skill);
      }

      // 解析失败，手动创建
      final manualSkill = Skill(
        id: skillId,
        metadata: SkillMetadata(
          name: skillId,
          description: '自动学习的技能',
        ),
        body: content,
      );
      return installSkill(manualSkill);
    } catch (e) {
      debugPrint('[SkillManager] 保存学习技能失败: $e');
      return false;
    }
  }
}

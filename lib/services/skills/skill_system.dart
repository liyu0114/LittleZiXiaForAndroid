// Skill 系统
//
// 完全兼容 OpenClaw 的 skill 格式

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
    if (lines.isEmpty || lines.first.trim() != '---') {
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
    return (_parseYaml(frontmatter), body);
  }

  static Map<String, dynamic> _parseYaml(String yaml) {
    final result = <String, dynamic>{};
    for (final line in yaml.split('\n')) {
      if (line.trim().isEmpty) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        var value = line.substring(colonIndex + 1).trim();
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
}

/// Skill 执行器
class SkillExecutor {
  final http.Client _client = http.Client();

  /// 执行 skill
  Future<String> execute(Skill skill, Map<String, dynamic> params) async {
    if (!skill.isSupported()) {
      return '⚠️ 当前平台不支持此 Skill';
    }

    // 解析 body 中的指令
    final instructions = _parseInstructions(skill.body);
    
    for (final instruction in instructions) {
      switch (instruction.type) {
        case _InstructionType.http:
          return await _executeHttp(instruction, params);
        case _InstructionType.builtin:
          return _executeBuiltin(instruction, params);
      }
    }

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

    // 匹配 curl 命令
    final curlRegex = RegExp(r'curl\s+["\x27]([^"\x27]+)["\x27]');
    for (final match in curlRegex.allMatches(body)) {
      instructions.add(_Instruction(_InstructionType.http, 'GET ${match.group(1)}'));
    }

    return instructions;
  }

  Future<String> _executeHttp(_Instruction instruction, Map<String, dynamic> params) async {
    try {
      String url = instruction.content.trim();
      if (url.startsWith('GET ')) url = url.substring(4).trim();
      
      // 替换参数
      params.forEach((key, value) {
        url = url.replaceAll('{$key}', value.toString());
      });

      final response = await _client.get(Uri.parse(url));
      return response.statusCode == 200 ? response.body.trim() : '请求失败: ${response.statusCode}';
    } catch (e) {
      return 'HTTP 执行错误: $e';
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
      if (expr == null) return '请提供计算表达式';
      try {
        final parts = expr.split(RegExp(r'([+\-*/])'));
        if (parts.length == 3) {
          final a = double.parse(parts[0]);
          final op = RegExp(r'([+\-*/])').firstMatch(expr)!.group(1)!;
          final b = double.parse(parts[2]);
          final result = switch (op) {
            '+' => a + b,
            '-' => a - b,
            '*' => a * b,
            '/' => a / b,
            _ => throw FormatException('未知运算符'),
          };
          return '计算结果: $expr = $result';
        }
      } catch (e) {
        return '计算错误: $e';
      }
      return '表达式格式错误';
    }

    if (content == 'random') {
      final min = params['min'] as int? ?? 1;
      final max = params['max'] as int? ?? 100;
      final random = DateTime.now().millisecondsSinceEpoch % (max - min + 1) + min;
      return '随机数 ($min-$max): $random';
    }

    return '未知内置指令: $content';
  }

  void dispose() => _client.close();
}

enum _InstructionType { http, builtin }

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

  SkillRegistry get registry => _registry;
  List<Skill> get availableSkills => _registry.available;

  /// 初始化：加载所有 Skills
  Future<void> initialize() async {
    debugPrint('[SkillManager] initialize() called, isLoaded=${_registry.isLoaded}');
    
    if (_registry.isLoaded) {
      debugPrint('[SkillManager] Already loaded, skipping');
      return;
    }

    debugPrint('[SkillManager] Loading skills from assets...');
    final skills = await _loader.loadFromAssets();
    debugPrint('[SkillManager] Loaded ${skills.length} skills');
    
    for (final skill in skills) {
      _registry.register(skill);
      debugPrint('[SkillManager] Registered: ${skill.id}');
    }
    
    _registry.markLoaded();
    debugPrint('[SkillManager] Total skills in registry: ${_registry.available.length}');
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
}

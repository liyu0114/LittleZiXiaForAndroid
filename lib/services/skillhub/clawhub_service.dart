// ClawHub 技能市场服务
//
// 从 ClawHub (https://clawhub.com) 获取技能列表

import 'dart:convert';
import 'package:http/http.dart' as http;

/// ClawHub 技能信息
class ClawHubSkill {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String downloadUrl;
  final String? homepage;
  final List<String> tags;
  final int downloads;
  final DateTime? updatedAt;

  ClawHubSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.downloadUrl,
    this.homepage,
    this.tags = const [],
    this.downloads = 0,
    this.updatedAt,
  });

  factory ClawHubSkill.fromJson(Map<String, dynamic> json) {
    return ClawHubSkill(
      id: json['id'] ?? json['name'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      author: json['author'] ?? 'Unknown',
      version: json['version'] ?? '1.0.0',
      downloadUrl: json['downloadUrl'] ?? json['url'] ?? '',
      homepage: json['homepage'],
      tags: List<String>.from(json['tags'] ?? []),
      downloads: json['downloads'] ?? 0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) 
          : null,
    );
  }
}

/// ClawHub 服务
class ClawHubService {
  static const String _baseUrl = 'https://clawhub.com/api';

  /// 获取技能列表
  Future<List<ClawHubSkill>> fetchSkills({String? category, String? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl/skills').replace(
        queryParameters: {
          if (category != null) 'category': category,
          if (query != null) 'q': query,
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final skills = data['skills'] as List? ?? [];
        return skills.map((s) => ClawHubSkill.fromJson(s)).toList();
      }

      // 返回模拟数据（用于离线测试）
      return _getMockSkills();
    } catch (e) {
      print('[ClawHubService] 获取技能列表失败: $e');
      // 返回模拟数据
      return _getMockSkills();
    }
  }

  /// 获取技能详情
  Future<ClawHubSkill?> fetchSkillDetail(String skillId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/skills/$skillId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ClawHubSkill.fromJson(data);
      }
      return null;
    } catch (e) {
      print('[ClawHubService] 获取技能详情失败: $e');
      return null;
    }
  }

  /// 下载技能内容
  Future<String?> downloadSkill(String downloadUrl) async {
    try {
      final response = await http.get(
        Uri.parse(downloadUrl),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      print('[ClawHubService] 下载技能失败: $e');
      return null;
    }
  }

  /// 模拟数据（离线测试用）
  List<ClawHubSkill> _getMockSkills() {
    return [
      ClawHubSkill(
        id: 'weather',
        name: '天气查询',
        description: '查询指定城市的天气情况，支持全球城市',
        author: 'OpenClaw',
        version: '1.0.0',
        downloadUrl: 'https://clawhub.com/skills/weather/SKILL.md',
        tags: ['天气', '查询', '基础'],
        downloads: 1234,
      ),
      ClawHubSkill(
        id: 'web_search',
        name: '网页搜索',
        description: '使用 Brave Search API 搜索互联网信息',
        author: 'OpenClaw',
        version: '1.1.0',
        downloadUrl: 'https://clawhub.com/skills/web_search/SKILL.md',
        tags: ['搜索', '网络', '基础'],
        downloads: 2345,
      ),
      ClawHubSkill(
        id: 'calculator',
        name: '计算器',
        description: '执行数学计算，支持基本运算和科学计算',
        author: 'OpenClaw',
        version: '1.0.0',
        downloadUrl: 'https://clawhub.com/skills/calculator/SKILL.md',
        tags: ['计算', '数学', '基础'],
        downloads: 987,
      ),
      ClawHubSkill(
        id: 'reminder',
        name: '提醒助手',
        description: '设置定时提醒，支持自然语言时间表达',
        author: 'OpenClaw',
        version: '1.2.0',
        downloadUrl: 'https://clawhub.com/skills/reminder/SKILL.md',
        tags: ['提醒', '时间', '实用'],
        downloads: 1567,
      ),
      ClawHubSkill(
        id: 'translator',
        name: '翻译助手',
        description: '多语言翻译，支持 100+ 语言',
        author: 'OpenClaw',
        version: '1.0.0',
        downloadUrl: 'https://clawhub.com/skills/translator/SKILL.md',
        tags: ['翻译', '语言', '实用'],
        downloads: 3456,
      ),
      ClawHubSkill(
        id: 'code_review',
        name: '代码审查',
        description: '分析代码质量，提供改进建议',
        author: 'Community',
        version: '1.0.0',
        downloadUrl: 'https://clawhub.com/skills/code_review/SKILL.md',
        tags: ['代码', '开发', '高级'],
        downloads: 567,
      ),
      ClawHubSkill(
        id: 'image_gen',
        name: '图像生成',
        description: '使用 DALL-E 或 Stable Diffusion 生成图像',
        author: 'Community',
        version: '1.0.0',
        downloadUrl: 'https://clawhub.com/skills/image_gen/SKILL.md',
        tags: ['图像', 'AI', '高级'],
        downloads: 890,
      ),
    ];
  }
}

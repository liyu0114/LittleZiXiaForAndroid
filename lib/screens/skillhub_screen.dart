// SkillHub 技能市场
//
// 从 OpenClaw SkillHub 同步、浏览、安装技能

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';

/// SkillHub 技能模型
class SkillHubItem {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final List<String> tags;
  final String downloadUrl;
  bool isInstalled;
  bool isInstalling;

  SkillHubItem({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.tags,
    required this.downloadUrl,
    this.isInstalled = false,
    this.isInstalling = false,
  });

  factory SkillHubItem.fromJson(Map<String, dynamic> json) {
    return SkillHubItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      version: json['version'] ?? '1.0.0',
      author: json['author'] ?? 'Unknown',
      tags: List<String>.from(json['tags'] ?? []),
      downloadUrl: json['download_url'] ?? '',
      isInstalled: json['is_installed'] ?? false,
    );
  }
}

class SkillHubScreen extends StatefulWidget {
  const SkillHubScreen({super.key});

  @override
  State<SkillHubScreen> createState() => _SkillHubScreenState();
}

class _SkillHubScreenState extends State<SkillHubScreen> {
  List<SkillHubItem> _skills = [];
  List<SkillHubItem> _filteredSkills = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // SkillHub API URL
  static const String _skillHubUrl = 'https://clawhub.com/api/skills';

  @override
  void initState() {
    super.initState();
    _loadLocalSkills();
  }

  /// 加载本地已安装的技能
  void _loadLocalSkills() {
    final appState = context.read<AppState>();
    final installedSkillIds = appState.skillRegistry.available.map((s) => s.id).toSet();
    
    // 更新已安装状态
    for (var skill in _skills) {
      skill.isInstalled = installedSkillIds.contains(skill.id);
    }
    
    setState(() {
      _filteredSkills = _skills;
    });
  }

  /// 从 SkillHub 同步技能列表
  Future<void> _syncFromSkillHub() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(_skillHubUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> skillsJson = data['skills'] ?? [];

        final appState = context.read<AppState>();
        final installedSkillIds = appState.skillRegistry.available.map((s) => s.id).toSet();

        setState(() {
          _skills = skillsJson.map((json) {
            final item = SkillHubItem.fromJson(json);
            item.isInstalled = installedSkillIds.contains(item.id);
            return item;
          }).toList();
          _filteredSkills = _skills;
          _isSyncing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 同步成功，共 ${_skills.length} 个技能'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _errorMessage = '同步失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $_errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 安装技能
  Future<void> _installSkill(SkillHubItem skill) async {
    setState(() {
      skill.isInstalling = true;
    });

    try {
      // TODO: 实现真实的技能下载和安装
      // 1. 下载 SKILL.md 文件
      // 2. 解析并注册到 SkillRegistry
      // 3. 保存到本地

      await Future.delayed(const Duration(seconds: 2)); // 模拟下载

      final appState = context.read<AppState>();
      final newSkill = Skill(
        id: skill.id,
        metadata: SkillMetadata(
          name: skill.name,
          description: skill.description,
        ),
        body: '',
      );
      
      appState.skillRegistry.register(newSkill);

      setState(() {
        skill.isInstalled = true;
        skill.isInstalling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${skill.name} 安装成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        skill.isInstalling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 安装失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 卸载技能
  Future<void> _uninstallSkill(SkillHubItem skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('卸载 ${skill.name}?'),
        content: const Text('确定要卸载这个技能吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('卸载'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final appState = context.read<AppState>();
      appState.skillRegistry.unregister(skill.id);

      setState(() {
        skill.isInstalled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 卸载成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 卸载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 测试技能
  void _testSkill(SkillHubItem skill) {
    if (!skill.isInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先安装技能'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('测试 ${skill.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('测试方法：'),
            const SizedBox(height: 8),
            const Text('1. 切换到对话界面'),
            const Text('2. 输入相关指令测试'),
            const SizedBox(height: 16),
            Text('例如："${skill.name}测试"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 搜索技能
  void _filterSkills(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSkills = _skills;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredSkills = _skills.where((skill) {
          return skill.name.toLowerCase().contains(lowerQuery) ||
              skill.description.toLowerCase().contains(lowerQuery) ||
              skill.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 SkillHub 技能市场'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncFromSkillHub,
            tooltip: '从 SkillHub 同步',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜索技能',
                hintText: '输入技能名称、描述或标签',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterSkills('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterSkills,
            ),
          ),

          // 统计信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '共 ${_skills.length} 个技能',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  '已安装 ${_skills.where((s) => s.isInstalled).length} 个',
                  style: TextStyle(color: Colors.green[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 错误提示
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // 技能列表
          Expanded(
            child: _skills.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _syncFromSkillHub,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredSkills.length,
                      itemBuilder: (context, index) {
                        return _buildSkillCard(_filteredSkills[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_download, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有技能列表',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角的同步按钮从 SkillHub 获取',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _syncFromSkillHub,
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? '同步中...' : '同步技能'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(SkillHubItem skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和状态
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (skill.isInstalled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            '已安装',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'v${skill.version}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 描述
            Text(
              skill.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 8),

            // 标签
            if (skill.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: skill.tags.take(3).map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    labelStyle: const TextStyle(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),

            // 作者
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '作者: ${skill.author}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (skill.isInstalled) ...[
                  // 测试按钮
                  TextButton.icon(
                    onPressed: () => _testSkill(skill),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('测试'),
                  ),
                  const SizedBox(width: 8),
                  // 卸载按钮
                  TextButton.icon(
                    onPressed: () => _uninstallSkill(skill),
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text('卸载', style: TextStyle(color: Colors.red)),
                  ),
                ] else ...[
                  // 安装按钮
                  ElevatedButton.icon(
                    onPressed: skill.isInstalling ? null : () => _installSkill(skill),
                    icon: skill.isInstalling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: Text(skill.isInstalling ? '安装中...' : '安装'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

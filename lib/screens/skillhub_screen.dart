// SkillHub 技能市场
//
// 从 OpenClaw SkillHub 同步、浏览、安装技能

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';
import '../services/skills/clawhub_service.dart';

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
      // 使用 ClawHubService 的推荐技能列表
      final clawhubService = ClawHubService();
      final recommendedSkills = await clawhubService.getPopularSkills(limit: 50);

      final appState = context.read<AppState>();
      final installedSkillIds = appState.skillRegistry.available.map((s) => s.id).toSet();

      setState(() {
        _skills = recommendedSkills.map((skill) {
          final item = SkillHubItem(
            id: skill.slug,
            name: skill.name,
            description: skill.description,
            version: skill.version ?? '1.0.0',
            author: 'Community',
            tags: skill.tags,
            downloadUrl: skill.homepage ?? '',
            isInstalled: installedSkillIds.contains(skill.slug),
          );
          return item;
        }).toList();
        _filteredSkills = _skills;
        _isSyncing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 同步成功，共 ${_skills.length} 个推荐技能'),
            backgroundColor: Colors.green,
          ),
        );
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

  /// 搜索技能
  void _filterSkills(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredSkills = _skills;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    setState(() {
      _filteredSkills = _skills.where((skill) {
        return skill.name.toLowerCase().contains(queryLower) ||
               skill.description.toLowerCase().contains(queryLower) ||
               skill.tags.any((tag) => tag.toLowerCase().contains(queryLower));
      }).toList();
    });
  }

  /// 安装技能
  Future<void> _installSkill(SkillHubItem skill) async {
    setState(() {
      skill.isInstalling = true;
    });

    try {
      // TODO: 实际的安装逻辑
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        skill.isInstalled = true;
        skill.isInstalling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已安装 ${skill.name}'),
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
    try {
      // TODO: 实际的卸载逻辑
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        skill.isInstalled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已卸载 ${skill.name}'),
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final installedCount = _skills.where((s) => s.isInstalled).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SkillHub 技能市场'),
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
            tooltip: '同步技能',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索技能...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: _filterSkills,
            ),
          ),

          // 统计信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text('共 ${_skills.length} 个技能'),
                const SizedBox(width: 16),
                Text('已安装 $installedCount 个'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 错误提示
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),

          // 技能列表
          Expanded(
            child: _skills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.extension,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '还没有技能列表',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右上角的同步按钮从 SkillHub 获取',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredSkills.length,
                    itemBuilder: (context, index) {
                      final skill = _filteredSkills[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: skill.isInstalled
                                ? Colors.green
                                : Colors.blue,
                            child: Icon(
                              skill.isInstalled
                                  ? Icons.check
                                  : Icons.extension,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(skill.name),
                          subtitle: Text(
                            skill.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: skill.isInstalling
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    if (skill.isInstalled) {
                                      _uninstallSkill(skill);
                                    } else {
                                      _installSkill(skill);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: skill.isInstalled
                                        ? Colors.red
                                        : Colors.blue,
                                  ),
                                  child: Text(
                                    skill.isInstalled ? '卸载' : '安装',
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

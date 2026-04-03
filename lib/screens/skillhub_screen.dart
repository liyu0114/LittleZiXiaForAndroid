// SkillHub 技能市场
//
// 从 OpenClaw SkillHub 同步、浏览、安装技能

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isMobileFriendly;  // 是否适合移动端
  bool isInstalled;
  bool isInstalling;
  bool isSelected;  // 是否选中（用于批量选择）

  SkillHubItem({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.tags,
    required this.downloadUrl,
    this.isMobileFriendly = true,
    this.isInstalled = false,
    this.isInstalling = false,
    this.isSelected = false,
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
      isMobileFriendly: json['mobile_friendly'] ?? true,
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
  
  // 选择模式
  bool _selectionMode = false;

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
          // 判断是否适合移动端
          final isMobileFriendly = skill.tags.contains('mobile') || 
              !skill.tags.contains('cli') && 
              !skill.tags.contains('desktop');
          
          final item = SkillHubItem(
            id: skill.slug,
            name: skill.name,
            description: skill.description,
            version: skill.version ?? '1.0.0',
            author: 'Community',
            tags: skill.tags,
            downloadUrl: skill.homepage ?? '',
            isMobileFriendly: isMobileFriendly,
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
            content: Text('✅ 同步成功，共 ${_skills.length} 个技能'),
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
      final appState = context.read<AppState>();
      
      // 从 ClawHub 获取真实的 SKILL.md 内容
      String? skillBody;
      
      // 1. 尝试从 Gateway API 获取
      try {
        final clawhub = ClawHubService();
        skillBody = await clawhub.getSkillContent(skill.id);
        if (skillBody != null && skillBody.isNotEmpty) {
          debugPrint('[SkillHub] 从 API 获取技能内容: ${skill.id}');
        }
      } catch (e) {
        debugPrint('[SkillHub] API 获取失败: $e');
      }
      
      // 2. 如果 API 获取失败，尝试从 assets 加载
      if (skillBody == null || skillBody.isEmpty) {
        try {
          // 尝试从 assets 加载预置技能
          final assetPath = 'assets/skills/${skill.id}/SKILL.md';
          skillBody = await rootBundle.loadString(assetPath);
          debugPrint('[SkillHub] 从 assets 加载技能: ${skill.id}');
        } catch (e) {
          debugPrint('[SkillHub] assets 加载失败: $e');
        }
      }
      
      // 3. 如果都没有，使用内置的技能模板（包含 http 指令）
      if (skillBody == null || skillBody.isEmpty) {
        skillBody = _getBuiltinSkillTemplate(skill.id, skill.name, skill.description);
        debugPrint('[SkillHub] 使用内置模板: ${skill.id}');
      }
      
      debugPrint('[SkillHub] 安装技能: ${skill.id}, body长度: ${skillBody.length}');
      
      // 创建技能对象
      final newSkill = Skill(
        id: skill.id,
        metadata: SkillMetadata(
          name: skill.name,
          description: skill.description,
          homepage: skill.downloadUrl,
        ),
        body: skillBody,
      );
      
      // 添加到注册表
      appState.skillRegistry.register(newSkill);
      
      // 刷新 UI
      appState.notifyListeners();

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
      debugPrint('[SkillHub] 安装失败: $e');
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
  
  /// 获取内置技能模板（包含可执行指令）
  String _getBuiltinSkillTemplate(String skillId, String skillName, String skillDescription) {
    // 根据技能 ID 返回对应的模板（包含 http 指令）
    switch (skillId) {
      case 'weather':
        return '''---
name: weather
description: $skillDescription
---

# Weather

Get current weather info.

## Current Weather

\`\`\`http
GET https://wttr.in/{location}?format=3
\`\`\`

## Parameters

- \`location\`: City name (e.g., "Beijing", "Nanning")
''';

      case 'translate':
        return '''---
name: translate
description: $skillDescription
---

# Translate

Translate text between languages.

## Translate Text

\`\`\`http
GET https://api.mymemory.translated.net/get?q={text}&langpair={from}|{to}
\`\`\`

## Parameters

- \`text\`: Text to translate
- \`from\`: Source language code (e.g., en, zh, ja)
- \`to\`: Target language code
''';

      case 'qrcode':
        return '''---
name: qrcode
description: $skillDescription
---

# QR Code Generator

Generate QR codes from text or URLs.

## Generate QR Code

\`\`\`http
GET https://api.qrserver.com/v1/create-qr-code/?size=300x300&data={content}
\`\`\`

## Parameters

- \`content\`: Text or URL to encode
- \`size\`: Image size (default: 300x300)
''';

      case 'ip-lookup':
        return '''---
name: ip-lookup
description: $skillDescription
---

# IP Lookup

Query IP address geolocation information.

## Lookup IP

\`\`\`http
GET http://ip-api.com/json/{ip}
\`\`\`

## Parameters

- \`ip\`: IP address to lookup (omit for current IP)
''';

      default:
        // 默认模板（无 http 指令）
        return '''---
name: $skillName
description: $skillDescription
---

# $skillName

$skillDescription

## 使用方法

此技能从 SkillHub 同步安装。

## 注意

此技能暂无可执行指令，请联系开发者完善。
''';
    }
  }
  
  /// 卸载技能
  Future<void> _uninstallSkill(SkillHubItem skill) async {
    try {
      final appState = context.read<AppState>();
      appState.skillRegistry.unregister(skill.id);
      appState.notifyListeners();

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
  
  /// 切换选择模式
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        // 退出选择模式时清空选择
        for (var skill in _skills) {
          skill.isSelected = false;
        }
      }
    });
  }
  
  /// 全选/取消全选
  void _toggleSelectAll() {
    final allSelected = _filteredSkills.every((s) => s.isSelected || s.isInstalled);
    setState(() {
      for (var skill in _filteredSkills) {
        if (!skill.isInstalled) {
          skill.isSelected = !allSelected;
        }
      }
    });
  }
  
  /// 批量安装选中的技能
  Future<void> _installSelected() async {
    final selectedSkills = _filteredSkills.where((s) => s.isSelected && !s.isInstalled).toList();
    
    if (selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要安装的技能')),
      );
      return;
    }
    
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量安装'),
        content: Text('确定要安装 ${selectedSkills.length} 个技能吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('安装'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 逐个安装
    for (var skill in selectedSkills) {
      await _installSkill(skill);
    }
    
    setState(() {
      _selectionMode = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 已安装 ${selectedSkills.length} 个技能'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  /// 测试技能
  void _testSkill(SkillHubItem skill) {
    // 跳转到技能测试界面
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('测试: ${skill.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(skill.description),
            const SizedBox(height: 16),
            if (!skill.isMobileFriendly)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('此技能可能不适合移动端'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('标签: ${skill.tags.join(", ")}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _installSkill(skill);
            },
            child: const Text('安装'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final installedCount = _skills.where((s) => s.isInstalled).length;
    final selectedCount = _filteredSkills.where((s) => s.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SkillHub 技能市场'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectAll,
              tooltip: '全选',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
              tooltip: '取消选择',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: '批量选择',
            ),
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
                Text('已安装: $installedCount', style: const TextStyle(color: Colors.green)),
                if (_selectionMode && selectedCount > 0) ...[
                  const SizedBox(width: 16),
                  Text('已选: $selectedCount', style: const TextStyle(color: Colors.blue)),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // 技能列表
          Expanded(
            child: _skills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_download, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('点击右上角同步按钮获取技能', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredSkills.length,
                    itemBuilder: (context, index) {
                      final skill = _filteredSkills[index];
                      return _buildSkillCard(skill);
                    },
                  ),
          ),
          
          // 批量操作栏
          if (_selectionMode && selectedCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text('已选择 $selectedCount 个技能'),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _installSelected,
                    icon: const Icon(Icons.download),
                    label: const Text('批量安装'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSkillCard(SkillHubItem skill) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _selectionMode
            ? Checkbox(
                value: skill.isSelected || skill.isInstalled,
                onChanged: skill.isInstalled 
                    ? null 
                    : (v) => setState(() => skill.isSelected = v ?? false),
              )
            : CircleAvatar(
                child: Text(skill.name[0]),
              ),
        title: Row(
          children: [
            Expanded(child: Text(skill.name)),
            if (!skill.isMobileFriendly)
              Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: skill.tags.take(3).map((tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ),
        trailing: skill.isInstalled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _uninstallSkill(skill),
                    tooltip: '卸载',
                  ),
                ],
              )
            : skill.isInstalling
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _testSkill(skill),
                        tooltip: '测试',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _installSkill(skill),
                        tooltip: '安装',
                      ),
                    ],
                  ),
        isThreeLine: true,
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

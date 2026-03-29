// 技能管理界面
//
// 支持查看、编辑、添加、删除技能，支持待安装列表

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';

enum SkillFilter { all, installed, pending }

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String? _selectedSkillId;
  SkillFilter _filter = SkillFilter.installed;
  late TabController _tabController;
  
  // 待安装技能列表（持久化到本地）
  List<Skill> _pendingSkills = [];
  
  // 已卸载的技能ID列表（持久化到本地，避免重新注册）
  List<String> _uninstalledSkillIds = [];
  
  // SkillHub 同步状态
  bool _isSyncing = false;
  String? _syncError;
  int _syncedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPersistedData();
  }
  
  Future<void> _loadPersistedData() async {
    // TODO: 从 SharedPreferences 加载持久化数据
    // 暂时使用内存存储
  }
  
  Future<void> _savePersistedData() async {
    // TODO: 保存到 SharedPreferences
  }

  /// 从 SkillHub 同步技能列表
  Future<void> _syncFromSkillHub() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    try {
      // SkillHub API URL
      const skillHubUrl = 'https://clawhub.com/api/skills';
      
      final response = await http.get(
        Uri.parse(skillHubUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> skillsJson = data['skills'] ?? [];
        
        int newCount = 0;
        for (final skillJson in skillsJson) {
          final skillId = skillJson['id'] as String?;
          if (skillId == null) continue;
          
          // 检查是否已存在
          final exists = _pendingSkills.any((s) => s.id == skillId);
          if (!exists) {
            final skill = Skill(
              id: skillId,
              metadata: SkillMetadata(
                name: skillJson['name'] ?? skillId,
                description: skillJson['description'] ?? '',
              ),
              body: skillJson['body'] ?? '',
            );
            _pendingSkills.add(skill);
            newCount++;
          }
        }
        
        setState(() {
          _isSyncing = false;
          _syncedCount = newCount;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 同步成功，新增 $newCount 个技能'),
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
        _syncError = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 同步失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // 检查技能是否已加载
        if (!appState.skillRegistry.isLoaded) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载技能...'),
                ],
              ),
            ),
          );
        }

        // 过滤掉已卸载的技能
        final installedSkills = appState.skillRegistry.available
            .where((s) => !_uninstalledSkillIds.contains(s.id))
            .toList();

        debugPrint('[SkillsScreen] Total skills: ${appState.skillRegistry.available.length}');
        debugPrint('[SkillsScreen] Installed skills: ${installedSkills.length}');
        debugPrint('[SkillsScreen] Uninstalled IDs: $_uninstalledSkillIds');
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('技能管理'),
            actions: [
              // SkillHub 同步按钮
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
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '已安装'),
                Tab(text: '待安装'),
                Tab(text: '总结技能'),
              ],
              onTap: (index) {
                setState(() {
                  if (index == 0) _filter = SkillFilter.installed;
                  else if (index == 1) _filter = SkillFilter.pending;
                  _selectedSkillId = null; // 切换标签时清除选中
                });
              },
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 已安装技能
              _buildInstalledSkillsView(appState, installedSkills),
              // 待安装技能
              _buildPendingSkillsView(appState),
              // 总结技能
              _buildSummarizeView(appState),
            ],
          ),
        );
      },
    );
  }

  // ==================== 已安装技能 ====================
  
  Widget _buildInstalledSkillsView(AppState appState, List<Skill> skills) {
    final filteredSkills = _searchQuery.isEmpty
        ? skills
        : skills.where((s) {
            final query = _searchQuery.toLowerCase();
            return s.metadata.name.toLowerCase().contains(query) ||
                s.metadata.description.toLowerCase().contains(query);
          }).toList();

    // 响应式布局：竖屏时上下布局，横屏时左右布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        
        if (isPortrait) {
          // 竖屏：上下布局
          return _buildPortraitLayout(filteredSkills, true);
        } else {
          // 横屏：左右布局
          return _buildLandscapeLayout(filteredSkills, true);
        }
      },
    );
  }
  
  Widget _buildPortraitLayout(List<Skill> skills, bool isInstalled) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: '搜索技能...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              isDense: true,
            ),
          ),
        ),
        
        // 技能统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isInstalled ? Icons.extension : Icons.download_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isInstalled 
                    ? '已安装 ${skills.length} 个技能'
                    : '待安装 ${skills.length} 个技能',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        
        // 技能列表
        Expanded(
          child: skills.isEmpty
              ? _buildEmptyState(isInstalled)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: skills.length,
                  itemBuilder: (context, index) {
                    final skill = skills[index];
                    final isSelected = _selectedSkillId == skill.id;
                    return _buildSkillCard(skill, isSelected, isInstalled);
                  },
                ),
        ),
        
        // 选中时显示详情卡片
        if (_selectedSkillId != null && skills.any((s) => s.id == _selectedSkillId))
          _buildDetailCard(skills.firstWhere((s) => s.id == _selectedSkillId), isInstalled),
      ],
    );
  }
  
  Widget _buildLandscapeLayout(List<Skill> skills, bool isInstalled) {
    return Row(
      children: [
        // 左侧：技能列表
        SizedBox(
          width: 280,
          child: Column(
            children: [
              // 搜索框
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: '搜索技能...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                ),
              ),

              // 技能统计
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isInstalled ? Icons.extension : Icons.download_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isInstalled 
                          ? '已安装 ${skills.length} 个技能'
                          : '待安装 ${skills.length} 个技能',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // 技能列表
              Expanded(
                child: skills.isEmpty
                    ? _buildEmptyState(isInstalled)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: skills.length,
                        itemBuilder: (context, index) {
                          final skill = skills[index];
                          final isSelected = _selectedSkillId == skill.id;
                          return _buildSkillListItem(skill, isSelected, isInstalled);
                        },
                      ),
              ),
            ],
          ),
        ),

        // 右侧：技能详情
        Expanded(
          child: _selectedSkillId == null || !skills.any((s) => s.id == _selectedSkillId)
              ? _buildEmptyDetail()
              : _buildSkillDetail(
                  skills.firstWhere((s) => s.id == _selectedSkillId),
                  isInstalled,
                ),
        ),
      ],
    );
  }
  
  Widget _buildDetailCard(Skill skill, bool isInstalled) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  skill.metadata.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isInstalled ? Colors.blue.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isInstalled ? '已安装' : '待安装',
                    style: TextStyle(
                      fontSize: 11,
                      color: isInstalled ? Colors.blue : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(skill.metadata.description),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isInstalled) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uninstallSkill(skill),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('卸载'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _testSkill(skill),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('测试'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _installSkill(skill),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('安装'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removePendingSkill(skill),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
  
  Widget _buildSkillCard(Skill skill, bool isSelected, bool isInstalled) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isInstalled
                ? Theme.of(context).colorScheme.secondaryContainer
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isInstalled ? Icons.extension : Icons.download_outlined,
            size: 20,
            color: isInstalled
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Colors.orange.shade700,
          ),
        ),
        title: Text(skill.metadata.name),
        subtitle: Text(
          skill.metadata.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          skill.isSupported() ? Icons.check_circle : Icons.error_outline,
          size: 20,
          color: skill.isSupported() ? Colors.green : Colors.orange,
        ),
        onTap: () => setState(() => _selectedSkillId = skill.id),
      ),
    );
  }

  Widget _buildEmptyState(bool isInstalled) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInstalled ? Icons.extension_off : Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isInstalled ? '暂无已安装技能' : '暂无待安装技能',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (!isInstalled) ...[
            const SizedBox(height: 8),
            Text(
              '从"总结技能"页面生成新技能',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillListItem(Skill skill, bool isSelected, bool isInstalled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedSkillId = skill.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isInstalled
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isInstalled ? Icons.extension : Icons.download_outlined,
                  size: 16,
                  color: isInstalled
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.metadata.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      skill.metadata.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                skill.isSupported() ? Icons.check_circle : Icons.error_outline,
                size: 16,
                color: skill.isSupported() ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '选择一个技能查看详情',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillDetail(Skill skill, bool isInstalled) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInstalled
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isInstalled ? Icons.extension : Icons.download_outlined,
                  size: 24,
                  color: isInstalled
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.metadata.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: skill.isSupported()
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            skill.isSupported() ? '可用' : '不可用',
                            style: TextStyle(
                              fontSize: 11,
                              color: skill.isSupported() ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isInstalled
                                ? Colors.blue.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isInstalled ? '已安装' : '待安装',
                            style: TextStyle(
                              fontSize: 11,
                              color: isInstalled ? Colors.blue : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 技能描述
          if (skill.metadata.description.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '描述',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    skill.metadata.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // SKILL.md 内容
          _buildSection('SKILL.md 源文件', [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '---',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'name: ${skill.metadata.name}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'description: "${skill.metadata.description}"',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '---',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      skill.body.isNotEmpty ? skill.body : '(无内容)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              if (isInstalled) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _uninstallSkill(skill),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('卸载'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _testSkill(skill),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('测试'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _installSkill(skill),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('安装'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _removePendingSkill(skill),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 待安装技能 ====================
  
  Widget _buildPendingSkillsView(AppState appState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        
        if (isPortrait) {
          return _buildPortraitLayout(_pendingSkills, false);
        } else {
          return _buildLandscapeLayout(_pendingSkills, false);
        }
      },
    );
  }

  // ==================== 总结技能 ====================
  
  Widget _buildSummarizeView(AppState appState) {
    final TextEditingController _conversationController = TextEditingController();
    final TextEditingController _skillNameController = TextEditingController();
    final TextEditingController _skillDescController = TextEditingController();
    final TextEditingController _skillBodyController = TextEditingController();
    
    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '从对话中总结并创建新技能。输入对话内容，AI将自动提取技能定义。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 对话输入
              Text('对话内容', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _conversationController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '粘贴对话内容...\n\n例如：\n用户：帮我查一下北京的天气\n助手：北京今天天气晴朗，温度25°C...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 总结按钮
              Center(
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: 调用LLM总结技能
                    setState(() {
                      _skillNameController.text = 'example_skill';
                      _skillDescController.text = '从对话中总结的示例技能';
                      _skillBodyController.text = '```http\nGET https://api.example.com/data\n```';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('技能已总结（演示）')),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('总结技能'),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 技能定义
              Text('技能定义', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              
              TextField(
                controller: _skillNameController,
                decoration: InputDecoration(
                  labelText: '技能名称',
                  hintText: '例如：weather',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextField(
                controller: _skillDescController,
                decoration: InputDecoration(
                  labelText: '技能描述',
                  hintText: '例如：获取天气信息',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextField(
                controller: _skillBodyController,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: '技能内容',
                  hintText: '```http\nGET https://api.example.com\n```',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              
              const SizedBox(height: 24),
              
              // 测试区域
              Text('测试', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('手工测试：请在对话中测试此技能')),
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('手工测试'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('自动测试功能开发中...')),
                        );
                      },
                      icon: const Icon(Icons.auto_mode),
                      label: const Text('自动测试'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 添加到待安装列表
              Center(
                child: FilledButton.icon(
                  onPressed: () {
                    if (_skillNameController.text.isEmpty ||
                        _skillDescController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写技能名称和描述')),
                      );
                      return;
                    }
                    
                    final newSkill = Skill(
                      id: _skillNameController.text,
                      metadata: SkillMetadata(
                        name: _skillNameController.text,
                        description: _skillDescController.text,
                      ),
                      body: _skillBodyController.text,
                    );
                    
                    this.setState(() {
                      _pendingSkills.add(newSkill);
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('技能 "${newSkill.id}" 已添加到待安装列表')),
                    );
                    
                    // 切换到待安装标签
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('添加到待安装列表'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 辅助方法 ====================
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  void _uninstallSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('卸载技能'),
        content: Text('确定要卸载技能 "${skill.metadata.name}" 吗？\n\n卸载后将移到待安装列表，且不会自动重新安装。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // 从已安装列表移除
              context.read<AppState>().skillRegistry.unregister(skill.id);
              
              // 添加到已卸载列表（防止自动重新注册）
              setState(() {
                _uninstalledSkillIds.add(skill.id);
              });
              
              // 添加到待安装列表
              setState(() {
                _pendingSkills.add(skill);
                _selectedSkillId = null;
              });
              
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('技能已卸载并移到待安装列表')),
              );
              
              _savePersistedData();
            },
            child: const Text('卸载'),
          ),
        ],
      ),
    );
  }

  void _installSkill(Skill skill) {
    // 注册技能
    context.read<AppState>().skillRegistry.register(skill);
    
    // 从已卸载列表移除
    setState(() {
      _uninstalledSkillIds.remove(skill.id);
      _pendingSkills.removeWhere((s) => s.id == skill.id);
      _selectedSkillId = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('技能 "${skill.id}" 已安装')),
    );
    
    _savePersistedData();
  }

  void _removePendingSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定要删除待安装技能 "${skill.metadata.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _pendingSkills.removeWhere((s) => s.id == skill.id);
                _selectedSkillId = null;
              });
              Navigator.pop(context);
              _savePersistedData();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _testSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('测试技能：${skill.metadata.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('测试方法：'),
            const SizedBox(height: 8),
            const Text('1. 切换到"对话"标签页'),
            const Text('2. 输入相关指令测试技能'),
            const SizedBox(height: 16),
            Text('例如："${skill.metadata.name}测试"'),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

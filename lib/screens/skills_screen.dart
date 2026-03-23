// 技能管理界面
//
// 支持查看、编辑、添加、删除技能，支持待安装列表

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  // 待安装技能列表（内存中）
  final List<Skill> _pendingSkills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Column(
          children: [
            // 标签栏
            TabBar(
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
                });
              },
            ),
            
            // 内容区域
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 已安装技能
                  _buildInstalledSkillsView(appState),
                  // 待安装技能
                  _buildPendingSkillsView(appState),
                  // 总结技能
                  _buildSummarizeView(appState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== 已安装技能 ====================
  
  Widget _buildInstalledSkillsView(AppState appState) {
    final skills = appState.skillRegistry.available;
    final filteredSkills = _searchQuery.isEmpty
        ? skills
        : skills.where((s) {
            final query = _searchQuery.toLowerCase();
            return s.metadata.name.toLowerCase().contains(query) ||
                s.metadata.description.toLowerCase().contains(query);
          }).toList();

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
                      Icons.extension,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已安装 ${skills.length} 个技能',
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
                child: filteredSkills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.extension_off,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? '暂无技能' : '未找到匹配的技能',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filteredSkills.length,
                        itemBuilder: (context, index) {
                          final skill = filteredSkills[index];
                          final isSelected = _selectedSkillId == skill.id;
                          return _buildSkillListItem(skill, isSelected, true);
                        },
                      ),
              ),
            ],
          ),
        ),

        // 右侧：技能详情
        Expanded(
          child: _selectedSkillId == null
              ? _buildEmptyDetail()
              : _buildSkillDetail(
                  skills.firstWhere((s) => s.id == _selectedSkillId),
                  true,
                ),
        ),
      ],
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

          // 基本信息
          _buildSection('基本信息', [
            _buildInfoRow('名称', skill.metadata.name),
            _buildInfoRow('描述', skill.metadata.description),
            if (skill.metadata.homepage != null)
              _buildInfoRow('主页', skill.metadata.homepage!),
            _buildInfoRow('路径', skill.path ?? '内置'),
          ]),

          const SizedBox(height: 24),

          // SKILL.md 内容
          _buildSection('SKILL.md 内容', [
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
    return Row(
      children: [
        // 左侧：待安装列表
        SizedBox(
          width: 280,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.download_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '待安装技能',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${_pendingSkills.length} 个',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: _pendingSkills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无待安装技能',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '从"总结技能"页面生成新技能',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _pendingSkills.length,
                        itemBuilder: (context, index) {
                          final skill = _pendingSkills[index];
                          final isSelected = _selectedSkillId == skill.id;
                          return _buildSkillListItem(skill, isSelected, false);
                        },
                      ),
              ),
            ],
          ),
        ),
        
        // 右侧：详情
        Expanded(
          child: _selectedSkillId == null || !_pendingSkills.any((s) => s.id == _selectedSkillId)
              ? _buildEmptyDetail()
              : _buildSkillDetail(
                  _pendingSkills.firstWhere((s) => s.id == _selectedSkillId),
                  false,
                ),
        ),
      ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _uninstallSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('卸载技能'),
        content: Text('确定要卸载技能 "${skill.metadata.name}" 吗？\n\n卸载后将移到待安装列表。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              // 从已安装列表移除
              context.read<AppState>().skillRegistry.unregister(skill.id);
              // 添加到待安装列表
              setState(() {
                _pendingSkills.add(skill);
              });
              setState(() => _selectedSkillId = null);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('技能已卸载并移到待安装列表')),
              );
            },
            child: const Text('卸载'),
          ),
        ],
      ),
    );
  }

  void _installSkill(Skill skill) {
    context.read<AppState>().skillRegistry.register(skill);
    setState(() {
      _pendingSkills.removeWhere((s) => s.id == skill.id);
    });
    setState(() => _selectedSkillId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('技能 "${skill.id}" 已安装')),
    );
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
              });
              setState(() => _selectedSkillId = null);
              Navigator.pop(context);
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

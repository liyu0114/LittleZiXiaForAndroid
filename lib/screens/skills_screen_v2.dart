// 技能管理界面 V2
//
// 完整的 Skill 生命周期管理：待测试 -> 待安装 -> 已安装

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';
import '../services/skills/skill_manager_new.dart';
import '../services/skills/skill_summarizer.dart';
import '../services/skills/skill_param_extractor.dart';
import '../services/skills/skill_share_service.dart';
import '../services/skills/skill_version_manager.dart';
import '../services/llm/llm_factory.dart';
import '../widgets/skill_editor.dart';

enum SkillTab { installed, pendingInstall, pendingTest, fromConversation }

class SkillsScreenV2 extends StatefulWidget {
  const SkillsScreenV2({super.key});

  @override
  State<SkillsScreenV2> createState() => _SkillsScreenV2State();
}

class _SkillsScreenV2State extends State<SkillsScreenV2> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  
  // 选中的技能
  ManagedSkill? _selectedManagedSkill;
  Skill? _selectedBuiltinSkill;
  
  // 编辑器控制器
  final TextEditingController _skillNameController = TextEditingController();
  final TextEditingController _skillDescController = TextEditingController();
  final TextEditingController _skillBodyController = TextEditingController();
  final TextEditingController _testParamsController = TextEditingController();
  
  // 从对话生成
  final TextEditingController _conversationController = TextEditingController();
  
  // 测试结果
  String? _testResult;
  bool _isTesting = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  void _onTabChanged() {
    setState(() {
      _selectedManagedSkill = null;
      _selectedBuiltinSkill = null;
      _testResult = null;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _skillNameController.dispose();
    _skillDescController.dispose();
    _skillBodyController.dispose();
    _testParamsController.dispose();
    _conversationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final skillManager = appState.enhancedSkillManager;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('技能管理'),
            actions: [
              // ClawHub 同步按钮
              IconButton(
                icon: skillManager.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                onPressed: skillManager.isSyncing 
                    ? null 
                    : () => _syncFromClawHub(skillManager),
                tooltip: '从 ClawHub 同步',
              ),
              // 更多选项
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleMenuAction(value, skillManager),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.file_upload),
                      title: Text('导入技能'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cleanup',
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services),
                      title: Text('清理旧版本'),
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '已安装'),
                Tab(text: '待安装'),
                Tab(text: '待测试'),
                Tab(text: '生成技能'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildInstalledTab(skillManager, appState),
              _buildPendingInstallTab(skillManager),
              _buildPendingTestTab(skillManager),
              _buildFromConversationTab(skillManager),
            ],
          ),
        );
      },
    );
  }

  // ==================== 已安装 ====================
  
  Widget _buildInstalledTab(EnhancedSkillManager manager, AppState appState) {
    // 使用 EnhancedSkillManager 的 baseManager.registry，因为它已经加载了技能
    final registry = manager.baseManager.registry;
    final isLoaded = registry.isLoaded;
    
    if (!isLoaded) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载技能...'),
          ],
        ),
      );
    }
    
    // 合并内置技能和已安装的托管技能
    final builtinSkills = registry.available;
    final installedManaged = manager.installedManagedSkills;
    
    debugPrint('[SkillsScreenV2] 内置技能数量: ${builtinSkills.length}');
    debugPrint('[SkillsScreenV2] 已安装托管技能数量: ${installedManaged.length}');
    
    final allInstalled = <dynamic>[
      ...builtinSkills,
      ...installedManaged.map((m) => m.skill),
    ];
    
    // 过滤搜索
    final filtered = _searchQuery.isEmpty
        ? allInstalled
        : allInstalled.where((s) {
            final skill = s as Skill;
            return skill.metadata.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   skill.metadata.description.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    return Column(
      children: [
        // 搜索框
        _buildSearchBar(),
        
        // 统计
        _buildStatsRow(
          Icons.extension,
          '已安装 ${filtered.length} 个技能',
          color: Colors.blue,
        ),
        
        // 列表
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('暂无已安装技能', Icons.extension_off)
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final skill = filtered[index] as Skill;
                    return _buildSkillListTile(
                      skill,
                      isSelected: _selectedBuiltinSkill?.id == skill.id,
                      onTap: () => setState(() {
                        _selectedBuiltinSkill = skill;
                        _selectedManagedSkill = null;
                      }),
                    );
                  },
                ),
        ),
        
        // 详情面板
        if (_selectedBuiltinSkill != null)
          _buildSkillDetailPanel(_selectedBuiltinSkill!),
      ],
    );
  }

  // ==================== 待安装 ====================
  
  Widget _buildPendingInstallTab(EnhancedSkillManager manager) {
    final skills = manager.pendingInstallSkills;
    
    final filtered = _searchQuery.isEmpty
        ? skills
        : skills.where((m) {
            return m.skill.metadata.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildStatsRow(
          Icons.download_done,
          '待安装 ${filtered.length} 个技能',
          color: Colors.green,
        ),
        
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('暂无待安装技能', Icons.inbox)
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final managed = filtered[index];
                    return _buildManagedSkillListTile(
                      managed,
                      isSelected: _selectedManagedSkill == managed,
                      onTap: () => setState(() {
                        _selectedManagedSkill = managed;
                        _selectedBuiltinSkill = null;
                        _loadSkillToEditor(managed.skill);
                      }),
                    );
                  },
                ),
        ),
        
        if (_selectedManagedSkill != null)
          _buildManagedSkillDetailPanel(_selectedManagedSkill!, manager),
      ],
    );
  }

  // ==================== 待测试 ====================
  
  Widget _buildPendingTestTab(EnhancedSkillManager manager) {
    final skills = manager.pendingTestSkills;
    
    final filtered = _searchQuery.isEmpty
        ? skills
        : skills.where((m) {
            return m.skill.metadata.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildStatsRow(
          Icons.science,
          '待测试 ${filtered.length} 个技能',
          color: Colors.orange,
        ),
        
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState('暂无待测试技能', Icons.science_outlined, 
                  subtitle: '从 ClawHub 同步技能')
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final managed = filtered[index];
                    return _buildManagedSkillListTile(
                      managed,
                      isSelected: _selectedManagedSkill == managed,
                      onTap: () => setState(() {
                        _selectedManagedSkill = managed;
                        _selectedBuiltinSkill = null;
                        _loadSkillToEditor(managed.skill);
                      }),
                    );
                  },
                ),
        ),
        
        if (_selectedManagedSkill != null)
          _buildTestPanel(_selectedManagedSkill!, manager),
      ],
    );
  }

  // ==================== 从对话生成 ====================
  
  Widget _buildFromConversationTab(EnhancedSkillManager manager) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                    '从对话中提取可复用的技能模式，生成新的 SKILL.md',
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
          const Text('对话内容', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _conversationController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: '粘贴对话内容...\n\n例如：\n用户：帮我查一下北京的天气\n助手：北京今天天气晴朗，温度25°C...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // AI 总结按钮
          Center(
            child: FilledButton.icon(
              onPressed: () => _summarizeFromConversation(manager),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 总结技能'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 技能定义
          const Text('技能定义', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
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
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'SKILL.md 内容',
              hintText: '---\nname: skill_name\ndescription: "技能描述"\n---\n\n```http\nGET https://api.example.com\n```',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          
          const SizedBox(height: 24),
          
          // 测试区域
          const Text('测试', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          TextField(
            controller: _testParamsController,
            decoration: InputDecoration(
              labelText: '测试参数 (JSON)',
              hintText: '{"location": "Beijing"}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : () => _testCurrentSkill(manager),
                  icon: _isTesting 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('测试'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _createSkillFromConversation(manager),
                  icon: const Icon(Icons.add_task),
                  label: const Text('添加到待测试'),
                ),
              ),
            ],
          ),
          
          // 测试结果
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('测试结果', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_testResult!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 辅助组件 ====================
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '搜索技能...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          isDense: true,
        ),
      ),
    );
  }
  
  Widget _buildStatsRow(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message, IconData icon, {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSkillListTile(Skill skill, {bool isSelected = false, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.extension, size: 20),
        ),
        title: Text(skill.metadata.name),
        subtitle: Text(skill.metadata.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          skill.isSupported() ? Icons.check_circle : Icons.error_outline,
          size: 20,
          color: skill.isSupported() ? Colors.green : Colors.orange,
        ),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildManagedSkillListTile(ManagedSkill managed, {bool isSelected = false, VoidCallback? onTap}) {
    final skill = managed.skill;
    Color statusColor;
    IconData statusIcon;
    
    switch (managed.status) {
      case SkillStatus.pendingTest:
        statusColor = Colors.orange;
        statusIcon = Icons.science;
        break;
      case SkillStatus.testFailed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SkillStatus.pendingInstall:
        statusColor = Colors.green;
        statusIcon = Icons.download_done;
        break;
      case SkillStatus.installed:
        statusColor = Colors.blue;
        statusIcon = Icons.extension;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, size: 20, color: statusColor),
        ),
        title: Text(skill.metadata.name),
        subtitle: Text(
          managed.errorMessage ?? skill.metadata.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: managed.status == SkillStatus.testFailed
              ? TextStyle(color: Colors.red.shade700)
              : null,
        ),
        trailing: Text(
          managed.source ?? 'local',
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSkillDetailPanel(Skill skill) {
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
                Text(skill.metadata.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('内置', style: TextStyle(fontSize: 11, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(skill.metadata.description),
          ],
        ),
      ),
    );
  }

  Widget _buildManagedSkillDetailPanel(ManagedSkill managed, EnhancedSkillManager manager) {
    final skill = managed.skill;
    
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
                Text(skill.metadata.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('待安装', style: TextStyle(fontSize: 11, color: Colors.green)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(skill.metadata.description),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _installManagedSkill(managed, manager),
                    icon: const Icon(Icons.install_mobile, size: 18),
                    label: const Text('安装'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _shareSkill(skill),
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: '分享',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _removeManagedSkill(managed, manager),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestPanel(ManagedSkill managed, EnhancedSkillManager manager) {
    final skill = managed.skill;
    
    // 使用新的参数提取器
    final extracted = SkillParamExtractor.extract(skill.body);
    final params = <String, String>{};
    for (final param in extracted.params) {
      params[param.name] = param.type;
    }
    final hasParams = params.isNotEmpty;
    
    return Container(
      height: 350,
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
                Text(managed.skill.metadata.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('待测试', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(managed.skill.metadata.description),
            
            const SizedBox(height: 16),
            
            // 自动提取的参数输入
            if (hasParams) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text('已提取 ${params.length} 个参数', 
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...params.entries.map((entry) {
                final param = _getParamInfo(managed, entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: param?.label ?? entry.key,
                      hintText: param?.placeholder ?? _getPlaceholder(entry.key),
                      helperText: param?.description,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      suffixIcon: param?.required == true 
                          ? Tooltip(message: '必填', child: Icon(Icons.star, size: 14, color: Colors.orange))
                          : null,
                    ),
                    onChanged: (value) => _updateTestParam(entry.key, value),
                  ),
                );
              }),
            ] else ...[
              // 没有参数
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text('此技能无需参数', 
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 测试按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : () => _testManagedSkill(managed, manager),
                    icon: _isTesting 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: const Text('测试'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _editManagedSkill(managed),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑'),
                  ),
                ),
              ],
            ),
            
            // 测试结果
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_testResult!, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // 临时存储测试参数
  final Map<String, String> _testParamValues = {};
  
  void _updateTestParam(String key, String value) {
    _testParamValues[key] = value;
  }
  
  /// 获取参数的详细信息
  SkillParam? _getParamInfo(ManagedSkill managed, String paramName) {
    final extracted = SkillParamExtractor.extract(managed.skill.body);
    try {
      return extracted.params.firstWhere((p) => p.name == paramName);
    } catch (_) {
      return null;
    }
  }
  
  /// 根据参数名获取占位符
  String _getPlaceholder(String paramName) {
    final lower = paramName.toLowerCase();
    if (lower.contains('location') || lower.contains('city')) return 'Beijing';
    if (lower.contains('ip')) return '8.8.8.8';
    if (lower.contains('query') || lower.contains('search')) return '搜索内容';
    if (lower.contains('url')) return 'https://example.com';
    return '输入 $paramName';
  }

  // ==================== 操作方法 ====================
  
  void _loadSkillToEditor(Skill skill) {
    _skillNameController.text = skill.metadata.name;
    _skillDescController.text = skill.metadata.description;
    _skillBodyController.text = skill.body;
  }
  
  Future<void> _syncFromClawHub(EnhancedSkillManager manager) async {
    final count = await manager.syncFromClawHub(mobileOnly: true);
    
    if (mounted) {
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 同步成功，新增 $count 个技能')),
        );
      } else if (manager.syncError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 同步失败: ${manager.syncError}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有新的技能')),
        );
      }
    }
  }
  
  Future<void> _testManagedSkill(ManagedSkill managed, EnhancedSkillManager manager) async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    
    try {
      // 从 TextField 解析测试参数
      Map<String, dynamic> params = {};
      
      // 尝试从 _testParamsController 解析 JSON
      if (_testParamsController.text.isNotEmpty) {
        try {
          params = Map<String, dynamic>.from(
            json.decode(_testParamsController.text) as Map
          );
        } catch (_) {
          // 解析失败， 忽略
        }
      }
      
      // 执行测试
      final result = await manager.executeSkill(managed.skill, params);
      
      setState(() {
        _testResult = result;
      });
      
      // 更新状态
      final success = await manager.testSkill(managed, params: params);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ 测试成功' : '❌ 测试失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }
  
  Future<void> _installManagedSkill(ManagedSkill managed, EnhancedSkillManager manager) async {
    final success = await manager.installSkill(managed);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 安装成功' : '❌ 安装失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      
      if (success) {
        setState(() {
          _selectedManagedSkill = null;
        });
      }
    }
  }
  
  Future<void> _removeManagedSkill(ManagedSkill managed, EnhancedSkillManager manager) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定要删除 "${managed.skill.metadata.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await manager.removeManagedSkill(managed);
      setState(() {
        _selectedManagedSkill = null;
      });
    }
  }
  
  void _editManagedSkill(ManagedSkill managed) {
    // 打开编辑对话框
    showDialog(
      context: context,
      builder: (context) => _SkillEditDialog(
        skill: managed.skill,
        onSave: (name, desc, body) async {
          // 更新技能内容
          final manager = context.read<AppState>().enhancedSkillManager;
          await manager.updateSkillContent(managed, body);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ 已保存，需要重新测试')),
            );
          }
        },
      ),
    );
  }
  
  /// 处理菜单操作
  void _handleMenuAction(String action, EnhancedSkillManager manager) {
    switch (action) {
      case 'import':
        _importSkill(manager);
        break;
      case 'cleanup':
        _cleanupOldVersions(manager);
        break;
    }
  }
  
  /// 导入技能
  Future<void> _importSkill(EnhancedSkillManager manager) async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入技能'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('粘贴技能数据（JSON 格式）:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{"version": "1.0", "id": "...", ...}',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    
    if (result != null && result.isNotEmpty) {
      final shareService = SkillShareService();
      final imported = shareService.importFromJson(result);
      
      if (imported != null) {
        final managed = await manager.createSkillFromConversation(
          name: imported.name,
          description: imported.description,
          body: imported.body,
        );
        
        if (managed != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ 已导入: ${imported.name}')),
          );
          _tabController.animateTo(2); // 切换到待测试
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 导入失败，格式不正确')),
        );
      }
    }
  }
  
  /// 分享技能
  Future<void> _shareSkill(Skill skill) async {
    final shareService = SkillShareService();
    final success = await shareService.shareSkill(skill);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 分享成功' : '❌ 分享失败'),
        ),
      );
    }
  }
  
  /// 查看版本历史
  Future<void> _viewVersionHistory(Skill skill) async {
    final versionManager = SkillVersionManager();
    final history = versionManager.getHistory(skill.id);
    
    if (!mounted) return;
    
    if (history == null || history.versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此技能没有版本历史')),
      );
      return;
    }
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${skill.metadata.name} - 版本历史'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ListView.builder(
            itemCount: history.versions.length,
            itemBuilder: (context, index) {
              final version = history.versions[index];
              final isCurrent = version.version == history.currentVersion;
              
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.history,
                  color: isCurrent ? Colors.green : null,
                ),
                title: Text('v${version.version}'),
                subtitle: Text(
                  '${version.createdAt.toLocal().toString().substring(0, 16)}'
                  '${version.changelog != null ? '\n${version.changelog}' : ''}',
                ),
                trailing: isCurrent 
                    ? const Chip(label: Text('当前'))
                    : TextButton(
                        onPressed: () async {
                          final rolledBack = await versionManager.rollback(
                            skill.id, 
                            version.version,
                          );
                          if (rolledBack != null && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已回滚到 v${version.version}')),
                            );
                          }
                        },
                        child: const Text('回滚'),
                      ),
              );
            },
          ),
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
  
  /// 清理旧版本
  Future<void> _cleanupOldVersions(EnhancedSkillManager manager) async {
    final versionManager = SkillVersionManager();
    
    // 获取所有已安装技能
    final installedSkills = manager.installedManagedSkills;
    int cleanedCount = 0;
    
    for (final managed in installedSkills) {
      final history = versionManager.getHistory(managed.skill.id);
      if (history != null && history.versions.length > 10) {
        await versionManager.cleanupOldVersions(managed.skill.id, keepCount: 10);
        cleanedCount++;
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 $cleanedCount 个技能的旧版本')),
      );
    }
  }
  
  Future<void> _testCurrentSkill(EnhancedSkillManager manager) async {
    if (_skillBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 SKILL.md 内容')),
      );
      return;
    }
    
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    
    try {
      // 创建临时技能
      final tempSkill = Skill(
        id: _skillNameController.text.isNotEmpty 
            ? _skillNameController.text 
            : 'temp_${DateTime.now().millisecondsSinceEpoch}',
        metadata: SkillMetadata(
          name: _skillNameController.text.isNotEmpty 
              ? _skillNameController.text 
              : 'temp_skill',
          description: _skillDescController.text,
        ),
        body: _skillBodyController.text,
      );
      
      // 解析测试参数
      Map<String, dynamic> params = {};
      if (_testParamsController.text.isNotEmpty) {
        try {
          params = Map<String, dynamic>.from(
            // 简单的 JSON 解析
            {},
          );
        } catch (_) {}
      }
      
      // 执行测试
      final result = await manager.executeSkill(tempSkill, params);
      
      setState(() {
        _testResult = result;
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }
  
  Future<void> _createSkillFromConversation(EnhancedSkillManager manager) async {
    if (_skillNameController.text.isEmpty ||
        _skillDescController.text.isEmpty ||
        _skillBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写技能名称、描述和内容')),
      );
      return;
    }
    
    final managed = await manager.createSkillFromConversation(
      name: _skillNameController.text,
      description: _skillDescController.text,
      body: _skillBodyController.text,
    );
    
    if (managed != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已添加到待测试列表')),
      );
      
      // 清空输入
      _conversationController.clear();
      _skillNameController.clear();
      _skillDescController.clear();
      _skillBodyController.clear();
      _testParamsController.clear();
      
      // 切换到待测试标签
      _tabController.animateTo(2);
    }
  }
  
  Future<void> _summarizeFromConversation(EnhancedSkillManager manager) async {
    final conversation = _conversationController.text.trim();
    
    if (conversation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入对话内容')),
      );
      return;
    }
    
    // 获取 LLM Provider
    final appState = context.read<AppState>();
    if (appState.llmConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置大模型')),
      );
      return;
    }
    
    // 显示加载
    setState(() => _isTesting = true);
    
    try {
      // 创建 SkillSummarizer
      final llmProvider = LLMFactory.create(appState.llmConfig!);
      final summarizer = SkillSummarizer(llmProvider);
      
      // 调用 AI 生成
      final generated = await summarizer.generateSkillMarkdown(conversation);
      
      if (generated != null) {
        // 填充到编辑器
        setState(() {
          _skillNameController.text = generated.name;
          _skillDescController.text = generated.description;
          _skillBodyController.text = generated.body;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 已生成技能: ${generated.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有识别到可复用的模式')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }
}

/// 技能编辑对话框
class _SkillEditDialog extends StatefulWidget {
  final Skill skill;
  final Future<void> Function(String name, String desc, String body) onSave;
  
  const _SkillEditDialog({required this.skill, required this.onSave});
  
  @override
  State<_SkillEditDialog> createState() => _SkillEditDialogState();
}

class _SkillEditDialogState extends State<_SkillEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _bodyController;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.skill.metadata.name);
    _descController = TextEditingController(text: widget.skill.metadata.description);
    _bodyController = TextEditingController(text: widget.skill.body);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑技能'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '技能名称',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '技能描述',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SimpleSkillEditor(
                initialContent: _bodyController.text,
                onChanged: (value) => _bodyController.text = value,
                minLines: 15,
                maxLines: 300,
                hintText: '输入 SKILL.md 内容...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onSave(
                      _nameController.text,
                      _descController.text,
                      _bodyController.text,
                    );
                    if (mounted) Navigator.pop(context);
                  } finally {
                    setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

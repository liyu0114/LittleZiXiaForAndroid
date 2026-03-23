// 技能管理界面
//
// 支持查看、编辑、添加、删除技能

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  String _searchQuery = '';
  String? _selectedSkillId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
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
                          '已加载 ${skills.length} 个技能',
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
                              return _buildSkillListItem(skill, isSelected);
                            },
                          ),
                  ),

                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddSkillDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _reloadSkills(),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('刷新'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 右侧：技能详情
            Expanded(
              child: _selectedSkillId == null
                  ? _buildEmptyDetail()
                  : _buildSkillDetail(skills.firstWhere((s) => s.id == _selectedSkillId)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkillListItem(Skill skill, bool isSelected) {
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
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.extension,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
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

  Widget _buildSkillDetail(Skill skill) {
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.extension,
                  size: 24,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteSkill(skill),
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
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
              child: SelectableText(
                '---\nname: ${skill.metadata.name}\ndescription: "${skill.metadata.description}"\n---\n\n${skill.body}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editSkill(skill),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
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
            ],
          ),
        ],
      ),
    );
  }

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

  void _showAddSkillDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加技能'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '技能名称',
                  hintText: '例如：weather',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '技能描述',
                  hintText: '例如：获取天气信息',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '技能内容（可选）',
                  hintText: '输入 ```http 或 ```builtin 代码块',
                  alignLabelWithHint: true,
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
            onPressed: () {
              // TODO: 实现添加技能
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('技能添加功能开发中...')),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _reloadSkills() {
    final appState = context.read<AppState>();
    appState.skillRegistry.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请重启应用以重新加载技能')),
    );
  }

  void _deleteSkill(Skill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定要删除技能 "${skill.metadata.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppState>().skillRegistry.unregister(skill.id);
              setState(() => _selectedSkillId = null);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _editSkill(Skill skill) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('技能编辑功能开发中...')),
    );
  }

  void _testSkill(Skill skill) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('测试技能: ${skill.metadata.name}')),
    );
  }
}

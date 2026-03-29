/// Skill 生命周期管理界面
///
/// 管理技能的完整生命周期：
/// 待测试 → 待安装 → 已安装 → 禁用

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/skills/skill_lifecycle.dart';

// 注意：这里假设 SkillLifecycleItem 已经导出
// 如果需要额外的类型定义，请确保导入正确

class SkillLifecycleScreen extends StatefulWidget {
  const SkillLifecycleScreen({super.key});

  @override
  State<SkillLifecycleScreen> createState() => _SkillLifecycleScreenState();
}

class _SkillLifecycleScreenState extends State<SkillLifecycleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技能管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '待测试'),
            Tab(text: '待安装'),
            Tab(text: '已安装'),
            Tab(text: '已禁用'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: 刷新技能列表
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('刷新功能开发中')),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final lifecycleManager = appState.lifecycleManager;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildSkillList(
                lifecycleManager.pendingTest,
                SkillStatus.pendingTest,
                appState,
              ),
              _buildSkillList(
                lifecycleManager.readyToInstall,
                SkillStatus.readyToInstall,
                appState,
              ),
              _buildSkillList(
                lifecycleManager.installed,
                SkillStatus.installed,
                appState,
              ),
              _buildSkillList(
                lifecycleManager.disabled,
                SkillStatus.disabled,
                appState,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenerateSkillDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('生成 Skill'),
      ),
    );
  }

  Widget _buildSkillList(
    List<SkillLifecycleItem> skills,
    SkillStatus status,
    AppState appState,
  ) {
    if (skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无${status.displayName}的技能',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        return _buildSkillCard(skill, status, appState);
      },
    );
  }

  Widget _buildSkillCard(
    SkillLifecycleItem skill,
    SkillStatus status,
    AppState appState,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    skill.skillName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(status.displayName),
                  backgroundColor: _getStatusColor(status),
                ),
              ],
            ),
            if (skill.description != null) ...[
              const SizedBox(height: 8),
              Text(
                skill.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (skill.source != null)
                  Chip(
                    label: Text(skill.source!),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ...skill.tags.map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActions(skill, status, appState),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    SkillLifecycleItem skill,
    SkillStatus status,
    AppState appState,
  ) {
    final actions = <Widget>[];

    switch (status) {
      case SkillStatus.pendingTest:
        actions.addAll([
          TextButton(
            onPressed: () => _testSkill(skill, appState),
            child: const Text('测试'),
          ),
          TextButton(
            onPressed: () => _editSkill(skill, appState),
            child: const Text('编辑'),
          ),
        ]);
        break;

      case SkillStatus.readyToInstall:
        actions.addAll([
          TextButton(
            onPressed: () => _installSkill(skill, appState),
            child: const Text('安装'),
          ),
          TextButton(
            onPressed: () => _editSkill(skill, appState),
            child: const Text('编辑'),
          ),
        ]);
        break;

      case SkillStatus.installed:
        actions.addAll([
          TextButton(
            onPressed: () => _disableSkill(skill, appState),
            child: const Text('禁用'),
          ),
          TextButton(
            onPressed: () => _uninstallSkill(skill, appState),
            child: const Text('卸载'),
          ),
        ]);
        break;

      case SkillStatus.disabled:
        actions.addAll([
          TextButton(
            onPressed: () => _enableSkill(skill, appState),
            child: const Text('启用'),
          ),
          TextButton(
            onPressed: () => _uninstallSkill(skill, appState),
            child: const Text('卸载'),
          ),
        ]);
        break;

      case SkillStatus.editing:
        actions.addAll([
          TextButton(
            onPressed: () => _testSkill(skill, appState),
            child: const Text('测试'),
          ),
        ]);
        break;
    }

    return actions;
  }

  Color _getStatusColor(SkillStatus status) {
    switch (status) {
      case SkillStatus.pendingTest:
        return Colors.orange.withOpacity(0.2);
      case SkillStatus.editing:
        return Colors.blue.withOpacity(0.2);
      case SkillStatus.readyToInstall:
        return Colors.green.withOpacity(0.2);
      case SkillStatus.installed:
        return Colors.purple.withOpacity(0.2);
      case SkillStatus.disabled:
        return Colors.grey.withOpacity(0.2);
    }
  }

  void _testSkill(SkillLifecycleItem skill, AppState appState) async {
    // TODO: 实现测试功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('测试技能: ${skill.skillName}')),
    );

    // 模拟测试成功
    await appState.lifecycleManager.markTestPassed(skill.skillId);
  }

  void _editSkill(SkillLifecycleItem skill, AppState appState) {
    // TODO: 打开编辑器
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('编辑技能: ${skill.skillName}')),
    );
  }

  void _installSkill(SkillLifecycleItem skill, AppState appState) async {
    final success = await appState.lifecycleManager.installSkill(skill.skillId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '安装成功' : '安装失败'),
        ),
      );
    }
  }

  void _disableSkill(SkillLifecycleItem skill, AppState appState) async {
    await appState.lifecycleManager.disableSkill(skill.skillId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已禁用')),
      );
    }
  }

  void _enableSkill(SkillLifecycleItem skill, AppState appState) async {
    await appState.lifecycleManager.enableSkill(skill.skillId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已启用')),
      );
    }
  }

  void _uninstallSkill(SkillLifecycleItem skill, AppState appState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载技能 "${skill.skillName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await appState.lifecycleManager.uninstallSkill(skill.skillId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已卸载')),
        );
      }
    }
  }

  void _showGenerateSkillDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const GenerateSkillDialog(),
    );
  }
}

/// 生成 Skill 对话框
class GenerateSkillDialog extends StatefulWidget {
  const GenerateSkillDialog({super.key});

  @override
  State<GenerateSkillDialog> createState() => _GenerateSkillDialogState();
}

class _GenerateSkillDialogState extends State<GenerateSkillDialog> {
  final _controller = TextEditingController();
  final _nameController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('从对话生成 Skill'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Skill 名称',
                hintText: '例如：天气查询',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: '对话内容',
                  hintText: '粘贴选中的对话...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isGenerating || _controller.text.isEmpty || _nameController.text.isEmpty
              ? null
              : _generateSkill,
          child: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('生成'),
        ),
      ],
    );
  }

  void _generateSkill() async {
    if (_controller.text.isEmpty || _nameController.text.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final appState = context.read<AppState>();
      
      // 调用 AppState 的方法生成 Skill
      final item = await appState.generateSkillFromConversation(
        _controller.text,
        _nameController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        
        if (item != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Skill "${item.skillName}" 生成成功，请前往待测试列表查看')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成失败: ${appState.error ?? "未知错误"}')),
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
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}

// 代码沙盒 - 项目列表页面

import 'package:flutter/material.dart';
import '../../services/sandbox/code_sandbox_service.dart';
import 'code_preview_screen.dart';

class SandboxScreen extends StatelessWidget {
  const SandboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sandbox = CodeSandboxService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('代码沙盒 🧪'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, sandbox),
            tooltip: '新建项目',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: sandbox,
        builder: (context, _) {
          final projects = sandbox.projects;

          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.code_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('还没有项目', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('让小紫霞帮你写一个程序吧！', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, sandbox),
                    icon: const Icon(Icons.add),
                    label: const Text('新建项目'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _ProjectCard(
                project: project,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CodePreviewScreen(project: project),
                    ),
                  );
                },
                onDelete: () {
                  _showDeleteConfirm(context, sandbox, project);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, CodeSandboxService sandbox) {
    final nameController = TextEditingController();
    String template = '空白项目';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新建项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '项目名称',
                  hintText: '我的计算器',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: template,
                decoration: const InputDecoration(
                  labelText: '模板',
                  border: OutlineInputBorder(),
                ),
                items: ['空白项目', '计算器', '待办清单', '时钟']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => template = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                sandbox.createProject(name);
                Navigator.pop(context);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, CodeSandboxService sandbox, CodeProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除 "${project.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              sandbox.deleteProject(project.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final CodeProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fileCount = project.files.length;
    final totalChars = project.files.values.fold(0, (a, b) => a + b.length);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Text(
            project.name.substring(0, project.name.length > 2 ? 2 : project.name.length),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '$fileCount 个文件 · $totalChars 字符 · ${_timeAgo(project.updatedAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

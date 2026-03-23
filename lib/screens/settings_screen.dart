import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            '对话管理',
            [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('清除对话历史'),
                subtitle: const Text('删除所有聊天记录'),
                onTap: () => _showClearDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出对话'),
                subtitle: const Text('导出聊天记录到文件'),
                onTap: () => _exportConversation(context),
              ),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('自动语音播放'),
                    subtitle: const Text('收到回复时自动播放语音'),
                    value: appState.ttsService.isInitialized,
                    onChanged: (value) {
                      // TODO: 实现语音开关
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('语音功能开发中...')),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            'Skill 管理',
            [
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('从对话总结 Skill'),
                    subtitle: const Text('分析对话历史，提取可复用模式'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _summarizeSkill(context, appState),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            '关于',
            [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('小紫霞'),
                subtitle: const Text('版本 0.2.1 (Build 3)'),
                onTap: () => _showAboutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                subtitle: const Text('查看使用的开源库'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '小紫霞',
                  applicationVersion: '0.2.1',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('反馈问题'),
                subtitle: const Text('报告 bug 或建议'),
                onTap: () => _openFeedback(),
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            '高级',
            [
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.cloud_outlined),
                    title: const Text('远程连接'),
                    subtitle: Text(
                      appState.isRemoteConnected
                          ? '已连接'
                          : '未连接',
                    ),
                    value: appState.capabilityConfig.l4Enabled,
                    onChanged: (value) async {
                      if (value) {
                        await appState.connectRemote();
                      } else {
                        appState.disconnectRemote();
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话历史'),
        content: const Text('确定要删除所有聊天记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().clearConversation();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('对话历史已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _exportConversation(BuildContext context) {
    final messages = context.read<AppState>().messages;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有对话记录')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('# 小紫霞对话记录');
    buffer.writeln('# 导出时间: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final msg in messages) {
      final role = msg.role == MessageRole.user ? '用户' : '小紫霞';
      buffer.writeln('### $role (${msg.timestamp.toIso8601String()})');
      buffer.writeln(msg.content);
      buffer.writeln();
    }

    // TODO: 实际保存到文件
    // 这里可以使用 file_picker 或 share 插件
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: '小紫霞',
        applicationVersion: '1.0.11 (Build 41)',
        applicationIcon: const Text('💜', style: TextStyle(fontSize: 48)),
        children: const [
          SizedBox(height: 16),
          Text('个人 AI 助理移动客户端'),
          SizedBox(height: 8),
          Text('支持多种大模型，可扩展能力层'),
        ],
      ),
    );
  }

  void _openFeedback() async {
    const url = 'https://github.com/openclaw/openclaw/issues';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _summarizeSkill(BuildContext context, AppState appState) async {
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在分析对话...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final skill = await appState.summarizeSkillFromConversation();

      // 清除加载提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (skill != null) {
        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 成功总结 Skill：${skill.name}\n\n${skill.description}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                _showSkillDetail(context, skill);
              },
            ),
          ),
        );
      } else {
        // 显示失败提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ℹ️ ${appState.error ?? "没有识别到可复用的模式"}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 清除加载提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 总结失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSkillDetail(BuildContext context, dynamic skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(skill.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('描述：${skill.description}'),
              const SizedBox(height: 8),
              Text('触发词：${skill.triggers.join(', ')}'),
              const SizedBox(height: 8),
              Text('匹配模式：${skill.pattern}'),
              const SizedBox(height: 8),
              Text('参数：'),
              ...skill.params.entries.map((e) => Text('  • ${e.key}: ${e.value}')),
              const SizedBox(height: 8),
              Text('模板：${skill.template}'),
            ],
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
}

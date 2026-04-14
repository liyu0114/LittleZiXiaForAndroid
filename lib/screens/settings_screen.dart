import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';
import 'memory_search_screen.dart';

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
                  final ttsService = appState.ttsService;
                  return SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('自动语音播放'),
                    subtitle: Text(
                      ttsService.autoPlayEnabled
                          ? '收到回复时自动播放语音'
                          : '已关闭',
                    ),
                    value: ttsService.autoPlayEnabled,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (value) async {
                      await ttsService.setAutoPlayEnabled(value);
                      appState.notifyListeners();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? '🔊 已开启自动语音播放'
                                  : '🔇 已关闭自动语音播放',
                            ),
                            backgroundColor:
                                value ? Colors.green : Colors.grey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            'Memory 管理',
            [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Memory 搜索'),
                subtitle: const Text('搜索保存的记忆'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MemorySearchScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('清除所有记忆'),
                subtitle: const Text('删除所有保存的记忆'),
                onTap: () => _showClearMemoryDialog(context),
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
                subtitle: const Text('版本 1.0.120 (Build 140)'),
                onTap: () => _showAboutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                subtitle: const Text('查看使用的开源库'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '小紫霞',
                  applicationVersion: '1.0.120 (Build 140)',
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
                      appState.isRemoteConnected ? '已连接' : '未连接',
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

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
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

  void _showClearMemoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有记忆'),
        content: const Text('确定要删除所有保存的记忆吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 实现清除记忆
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('记忆已清除')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: '小紫霞',
        applicationVersion: '1.0.120 (Build 140)',
        applicationIcon:
            const Text('💜', style: TextStyle(fontSize: 48)),
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

  Future<void> _summarizeSkill(
      BuildContext context, AppState appState) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('正在分析对话...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final skill = await appState.summarizeSkillFromConversation();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (skill != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 成功总结 Skill: ${skill.name}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ℹ️ ${appState.error ?? "没有识别到可复用的模式"}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 总结失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

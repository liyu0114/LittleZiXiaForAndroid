import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';
import '../services/llm/model_download_service.dart';
import '../config/app_version.dart';
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
            '本地模型管理',
            [
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('下载模型'),
                subtitle: const Text('下载 GGUF 大语言模型'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _showModelDownloadDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('已下载模型'),
                subtitle: const Text('管理本地模型文件'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {},
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
                subtitle: Text('版本 ${AppVersion.version} (Build ${AppVersion.buildNumber})'),
                onTap: () => _showAboutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源许可'),
                subtitle: const Text('查看使用的开源库'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '小紫霞',
                  applicationVersion: '${AppVersion.version} (Build ${AppVersion.buildNumber})',
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
        applicationVersion: '${AppVersion.version} (Build ${AppVersion.buildNumber})',
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
  
  // ============ 模型下载对话框 ============
  
  void _showModelDownloadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _ModelDownloadSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// 模型下载底部面板
class _ModelDownloadSheet extends StatefulWidget {
  final ScrollController scrollController;
  
  const _ModelDownloadSheet({required this.scrollController});
  
  @override
  State<_ModelDownloadSheet> createState() => _ModelDownloadSheetState();
}

class _ModelDownloadSheetState extends State<_ModelDownloadSheet> {
  String? _downloadingModelId;
  double _progress = 0;
  String? _error;
  
  @override
  Widget build(BuildContext context) {
    final models = ModelDownloadManager.getModels();
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.download_for_offline),
                const SizedBox(width: 8),
                const Text(
                  '下载本地模型',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // 模型列表
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final isDownloading = _downloadingModelId == model.id;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(model.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model.description),
                        Text('${model.sizeMB}MB', style: const TextStyle(fontSize: 12)),
                        if (isDownloading) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: _progress),
                          Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                        ],
                        if (_error != null && isDownloading)
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            onPressed: () => _downloadModel(model),
                            child: const Text('下载'),
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
  
  Future<void> _downloadModel(DownloadableModel model) async {
    setState(() {
      _downloadingModelId = model.id;
      _progress = 0;
      _error = null;
    });
    
    // 模拟下载进度（实际需要连接后端）
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _progress = i / 10);
    }
    
    setState(() {
      _downloadingModelId = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${model.name} 下载完成')),
      );
    }
  }
}



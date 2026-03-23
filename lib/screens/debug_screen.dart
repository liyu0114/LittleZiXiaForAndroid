// 调试页面
//
// 提供调试命令和日志查看功能

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/skills/skill_system.dart';
import '../config/app_version.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final List<String> _logs = [];
  
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
      if (_logs.length > 100) _logs.removeAt(0);
    });
    debugPrint('[Debug] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 应用信息
                    _buildAppInfoCard(appState),
                    const SizedBox(height: 16),
                    
                    // 技能状态详情
                    _buildSkillDetailCard(appState),
                    const SizedBox(height: 16),
                    
                    // 调试命令
                    _buildCommandCard(
                      context,
                      title: 'ADB 日志命令',
                      command: 'adb logcat | grep SkillLoader',
                      description: '在电脑上运行此命令查看技能加载日志',
                    ),
                    const SizedBox(height: 16),
                    
                    // 调试操作
                    _buildDebugActions(context, appState),
                    const SizedBox(height: 16),
                    
                    // 日志窗口
                    _buildLogWindow(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppInfoCard(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('应用信息', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('版本', AppVersion.fullDisplayVersion),
            _buildInfoRow('构建日期', AppVersion.buildDate),
            _buildInfoRow('平台', 'Android'),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillDetailCard(AppState appState) {
    final skills = appState.skillRegistry.available;
    final isLoaded = appState.skillRegistry.isLoaded;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('技能状态', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            
            // 状态指示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLoaded && skills.isNotEmpty
                    ? Colors.green.shade50 
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isLoaded && skills.isNotEmpty ? Icons.check_circle : Icons.warning,
                        color: isLoaded && skills.isNotEmpty ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '初始化: ${isLoaded ? "完成" : "未完成"} | 技能: ${skills.length}个',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLoaded && skills.isNotEmpty ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (skills.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('⚠️ 未加载到技能', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              const Text('可能原因:', style: TextStyle(fontWeight: FontWeight.w500)),
              const Text('  • assets 未正确打包'),
              const Text('  • SKILL.md 格式错误'),
              const Text('  • 初始化时机问题'),
              const SizedBox(height: 8),
              const Text('解决方法:', style: TextStyle(fontWeight: FontWeight.w500)),
              const Text('  • 点击"加载测试技能"验证系统'),
              const Text('  • 点击"重新加载技能"重试'),
              const Text('  • 查看下方日志窗口'),
            ] else ...[
              const SizedBox(height: 12),
              const Text('已加载技能:', style: TextStyle(fontWeight: FontWeight.w500)),
              ...skills.map((s) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${s.id}: ${s.metadata.description}')),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommandCard(
    BuildContext context, {
    required String title,
    required String command,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(command, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: command));
                      _addLog('命令已复制: $command');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                    tooltip: '复制',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugActions(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('加载测试技能'),
              subtitle: const Text('手动添加一个测试技能'),
              onTap: () => _loadTestSkill(context, appState),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('重新加载技能'),
              subtitle: const Text('清除并重新初始化'),
              onTap: () {
                appState.skillRegistry.clear();
                _addLog('已清除技能注册表');
                _addLog('当前技能数: ${appState.skillRegistry.available.length}');
                _addLog('请重启应用重新加载');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清除，请重启应用')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.output),
              title: const Text('输出调试日志'),
              subtitle: const Text('在日志窗口显示详细信息'),
              onTap: () {
                _addLog('=== 开始调试 ===');
                _addLog('版本: ${AppVersion.fullDisplayVersion}');
                _addLog('技能已加载: ${appState.skillRegistry.isLoaded}');
                _addLog('技能数量: ${appState.skillRegistry.available.length}');
                for (final skill in appState.skillRegistry.available) {
                  _addLog('技能: ${skill.id}');
                }
                _addLog('=== 调试结束 ===');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日志已输出到下方窗口')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogWindow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.article, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('日志窗口', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无日志\n点击上方按钮开始调试',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadTestSkill(BuildContext context, AppState appState) {
    _addLog('开始加载测试技能...');
    
    final testSkill = Skill(
      id: 'test',
      metadata: SkillMetadata(
        name: 'test',
        description: '测试技能',
      ),
      body: '```builtin\ntime\n```',
    );
    
    appState.skillRegistry.register(testSkill);
    _addLog('✓ 测试技能已注册');
    _addLog('当前技能数: ${appState.skillRegistry.available.length}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('测试技能已加载，当前 ${appState.skillRegistry.available.length} 个技能')),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

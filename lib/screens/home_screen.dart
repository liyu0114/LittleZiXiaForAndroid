import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/message_list.dart';
import '../widgets/message_input.dart';
import '../widgets/topic_sidebar.dart';
import '../services/file/file_picker_service.dart';
import '../services/conversation/topic_manager.dart';
import '../config/app_version.dart';
import 'llm_config_screen.dart';
import 'capability_screen.dart';
import 'skills_screen_v2.dart';
import 'skillhub_screen.dart';
import 'skill_lifecycle_screen.dart';
import 'settings_screen.dart';
import 'gateway_dashboard.dart';
import 'debug_screen.dart';
import 'sensor_data_screen.dart';
import 'group_chat_entry_screen.dart';  // 新增群聊入口
import 'twenty_four_game_screen.dart';  // 新增24点游戏屏幕

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late TabController _tabController;
  String? _selectedImagePath;
  String? _selectedVideoPath;
  FilePickResult? _selectedFile;
  bool _showTopicSidebar = false;  // 话题侧边栏开关

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 12, vsync: this);  // 12 个 tab
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final imagePath = _selectedImagePath;
    final videoPath = _selectedVideoPath;
    final fileResult = _selectedFile;
    
    if (content.isEmpty && imagePath == null && videoPath == null && fileResult == null) return;

    _messageController.clear();
    _selectedImagePath = null;
    _selectedVideoPath = null;
    _selectedFile = null;

    try {
      await context.read<AppState>().sendMessage(
        content,
        imagePath: imagePath,
        videoPath: videoPath,
        fileResult: fileResult,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  void _handleImagePicked(String path) {
    setState(() {
      _selectedImagePath = path;
      _selectedVideoPath = null;
      _selectedFile = null;
    });
  }

  void _handleVideoPicked(String path) {
    setState(() {
      _selectedVideoPath = path;
      _selectedImagePath = null;
      _selectedFile = null;
    });
  }

  void _handleFilePicked(FilePickResult result) {
    setState(() {
      _selectedFile = result;
      _selectedImagePath = null;
      _selectedVideoPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_showTopicSidebar ? Icons.close : Icons.menu),
          onPressed: () => setState(() => _showTopicSidebar = !_showTopicSidebar),
          tooltip: '话题列表',
        ),
        title: Consumer<AppState>(
          builder: (context, appState, child) {
            final topic = appState.topicManager.currentTopic;
            return GestureDetector(
              onTap: () => _showTopicTitleEditor(context, topic),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(topic?.displayTitle ?? '小紫霞'),
                  Text(
                    AppVersion.displayVersion,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: '对话'),
            Tab(icon: Icon(Icons.games), text: '24点'),  // 移到对话后面
            Tab(icon: Icon(Icons.smart_toy), text: '模型'),
            Tab(icon: Icon(Icons.tune), text: '能力'),
            Tab(icon: Icon(Icons.extension), text: '技能'),
            Tab(icon: Icon(Icons.cloud_download), text: 'SkillHub'),
            Tab(icon: Icon(Icons.auto_fix_high), text: '生命周期'),
            Tab(icon: Icon(Icons.people), text: '群聊'),
            Tab(icon: Icon(Icons.sensors), text: '传感器'),
            Tab(icon: Icon(Icons.settings), text: '设置'),
            Tab(icon: Icon(Icons.cloud), text: 'Gateway'),
            Tab(icon: Icon(Icons.bug_report), text: '调试'),
          ],
        ),
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              return Row(
                children: [
                  if (appState.capabilityConfig.l4Enabled)
                    Icon(
                      appState.isRemoteConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: appState.isRemoteConnected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      appState.hasLLMConfig ? Icons.check_circle : Icons.error_outline,
                      color: appState.hasLLMConfig ? Colors.green : Colors.orange,
                    ),
                    onPressed: () {
                      if (!appState.hasLLMConfig) {
                        _tabController.animateTo(2);  // 跳到模型页
                      }
                    },
                    tooltip: appState.hasLLMConfig ? '已配置' : '未配置',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 主内容
          TabBarView(
            controller: _tabController,
            children: [
              _buildChatTab(),
              const TwentyFourGameScreen(),  // 移到对话后面
              const LLMConfigScreen(),
              const CapabilityScreen(),
              const SkillsScreenV2(),
              const SkillHubScreen(),
              const SkillLifecycleScreen(),
              const GroupChatEntryScreen(),
              const SensorDataScreen(),
              const SettingsScreen(),
              const GatewayDashboard(),
              const DebugScreen(),
            ],
          ),
          // 话题侧边栏（滑出效果）
          if (_showTopicSidebar)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  return TopicSidebar(
                    topicManager: appState.topicManager,
                    onTopicSelected: (topic) {
                      appState.topicManager.switchTopic(topic.id);
                      setState(() => _showTopicSidebar = false);
                    },
                    onNewTopic: () {
                      appState.topicManager.createTopic();
                      setState(() => _showTopicSidebar = false);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showTopicTitleEditor(BuildContext context, ConversationTopic? topic) {
    if (topic == null) return;
    
    final controller = TextEditingController(text: topic.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名话题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入话题名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AppState>().topicManager.updateTopicTitle(topic.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (!appState.hasLLMConfig) {
          return _buildNoConfigView();
        }

        return Column(
          children: [
            // 话题信息栏
            if (appState.topicManager.currentTopic != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.topicManager.currentTopic!.displayTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    Text(
                      '${appState.topicManager.currentTopic!.messageCount} 条消息',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

            if (appState.isGenerating)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '正在思考...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

            if (appState.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: appState.messages.isEmpty
                  ? _buildEmptyView(appState)
                  : MessageList(messages: appState.messages),
            ),

            MessageInput(
              controller: _messageController,
              onSend: _sendMessage,
              onImagePicked: _handleImagePicked,
              onVideoPicked: _handleVideoPicked,
              onFilePicked: _handleFilePicked,
              enabled: !appState.isGenerating,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoConfigView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings_suggest, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('请先配置大模型', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('在"模型"标签页配置 API Key', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(2),  // 模型页现在是第3页（index 2）
            icon: const Icon(Icons.arrow_forward),
            label: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(AppState appState) {
    final levels = <String>[
      if (appState.capabilityConfig.l1Enabled) 'L1',
      if (appState.capabilityConfig.l2Enabled) 'L2',
      if (appState.capabilityConfig.l3Enabled) 'L3',
      if (appState.capabilityConfig.l4Enabled) 'L4',
    ].join('+');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('开始对话吧！', style: TextStyle(fontSize: 18, color: Colors.grey)),
          if (levels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('已启用 $levels', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          Text(
            '已加载 ${appState.skillRegistry.available.length} 个 skills',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          // 提示：点击左上角菜单查看话题
          Text(
            '💡 点击左上角菜单管理话题',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

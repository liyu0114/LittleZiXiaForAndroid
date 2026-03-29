// 话题列表抽屉组件
//
// 手机端使用底部抽屉，平板使用侧边栏

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/conversation/topic_manager.dart';

class TopicDrawer extends StatelessWidget {
  const TopicDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final topicManager = appState.topicManager;
        final activeTopics = topicManager.activeTopics;
        final groupedTopics = topicManager.groupByDate();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    const SizedBox(width: 8),
                    Text(
                      '我的话题',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${activeTopics.length} 个',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 搜索框
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索话题...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  onChanged: (query) {
                    // TODO: 实现搜索
                  },
                ),
              ),

              // 话题列表
              Expanded(
                child: groupedTopics.isEmpty
                    ? _buildEmptyState(context)
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: groupedTopics.entries.map((entry) {
                          return _buildDateGroup(
                            context,
                            entry.key,
                            entry.value,
                            topicManager,
                          );
                        }).toList(),
                      ),
              ),

              // 底部操作栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          topicManager.createTopic();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('新话题'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          // TODO: 管理话题
                        },
                        icon: const Icon(Icons.folder_outlined),
                        label: const Text('管理'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有话题',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击"新话题"开始对话',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(
    BuildContext context,
    String title,
    List<ConversationTopic> topics,
    TopicManager topicManager,
  ) {
    if (topics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        ...topics.map((topic) => _buildTopicCard(context, topic, topicManager)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    ConversationTopic topic,
    TopicManager topicManager,
  ) {
    final isCurrent = topicManager.currentTopic?.id == topic.id;
    final timeAgo = _formatTimeAgo(topic.lastActiveAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrent ? 2 : 0,
      color: isCurrent
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrent
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            topic.title.isNotEmpty ? topic.title[0] : '?',
            style: TextStyle(
              color: isCurrent
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        title: Text(
          topic.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '$timeAgo · ${topic.messageCount} 条消息',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        trailing: isCurrent
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () {
          if (!isCurrent) {
            topicManager.switchTopic(topic.id);
            Navigator.pop(context); // 关闭抽屉
          }
        },
        onLongPress: () {
          _showTopicOptions(context, topic, topicManager);
        },
      ),
    );
  }

  void _showTopicOptions(
    BuildContext context,
    ConversationTopic topic,
    TopicManager topicManager,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, topic, topicManager);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: () {
                topicManager.archiveTopic(topic.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                _confirmDelete(context, topic, topicManager);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ConversationTopic topic,
    TopicManager topicManager,
  ) {
    final controller = TextEditingController(text: topic.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名话题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              topicManager.updateTopicTitle(topic.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ConversationTopic topic,
    TopicManager topicManager,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除话题'),
        content: Text('确定要删除"${topic.displayTitle}"吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              topicManager.deleteTopic(topic.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${time.month}/${time.day}';
  }
}

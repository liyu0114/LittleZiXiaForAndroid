// 话题列表页面
//
// 显示所有话题，支持搜索和分组

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/conversation/topic_manager.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('话题管理'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
            },
            tooltip: _showArchived ? '隐藏归档' : '显示归档',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final topicManager = appState.topicManager;
          final groupedTopics = _showArchived
              ? {'归档': topicManager.archivedTopics}
              : topicManager.groupByDate();

          return Column(
            children: [
              // 搜索框
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索话题...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (query) {
                    setState(() => _searchQuery = query);
                  },
                ),
              ),

              // 统计信息
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildStatChip(
                      context,
                      Icons.chat_bubble_outline,
                      '${topicManager.activeTopics.length} 活跃',
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      context,
                      Icons.archive_outlined,
                      '${topicManager.archivedTopics.length} 归档',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 话题列表
              Expanded(
                child: groupedTopics.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groupedTopics.length,
                        itemBuilder: (context, index) {
                          final entry = groupedTopics.entries.elementAt(index);
                          return _buildDateGroup(
                            context,
                            entry.key,
                            entry.value,
                            topicManager,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final appState = context.read<AppState>();
          appState.topicManager.createTopic();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已创建新话题')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新话题'),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived ? Icons.archive : Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived ? '没有归档话题' : '还没有话题',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (!_showArchived) ...[
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮创建新话题',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
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
    // 过滤搜索结果
    final filteredTopics = _searchQuery.isEmpty
        ? topics
        : topicManager.searchTopics(_searchQuery);

    if (filteredTopics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${filteredTopics.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        ...filteredTopics.map(
          (topic) => _buildTopicTile(context, topic, topicManager),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTopicTile(
    BuildContext context,
    ConversationTopic topic,
    TopicManager topicManager,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(topic.title.isNotEmpty ? topic.title[0] : '?'),
        ),
        title: Text(
          topic.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${topic.messageCount} 条消息 · ${_formatTime(topic.lastActiveAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            if (topic.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                topic.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'switch',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz),
                  SizedBox(width: 8),
                  Text('切换到此话题'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('重命名'),
                ],
              ),
            ),
            if (topic.status == TopicStatus.active)
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined),
                    SizedBox(width: 8),
                    Text('归档'),
                  ],
                ),
              ),
            if (topic.status == TopicStatus.archived)
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.unarchive_outlined),
                    SizedBox(width: 8),
                    Text('恢复'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'switch':
                topicManager.switchTopic(topic.id);
                Navigator.pop(context);
                break;
              case 'rename':
                _showRenameDialog(context, topic, topicManager);
                break;
              case 'archive':
                topicManager.archiveTopic(topic.id);
                break;
              case 'restore':
                // TODO: 实现恢复功能
                break;
              case 'delete':
                _confirmDelete(context, topic, topicManager);
                break;
            }
          },
        ),
        onTap: () {
          topicManager.switchTopic(topic.id);
          Navigator.pop(context);
        },
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
          decoration: const InputDecoration(hintText: '输入新名称'),
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
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
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

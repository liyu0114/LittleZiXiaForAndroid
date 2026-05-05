// 话题侧边栏
//
// 学习 DeepSeek 的话题列表 UI

import 'package:flutter/material.dart';
import '../../services/conversation/topic_manager.dart';

class TopicSidebar extends StatefulWidget {
  final TopicManager topicManager;
  final Function(ConversationTopic) onTopicSelected;
  final VoidCallback onNewTopic;

  const TopicSidebar({
    super.key,
    required this.topicManager,
    required this.onTopicSelected,
    required this.onNewTopic,
  });

  @override
  State<TopicSidebar> createState() => _TopicSidebarState();
}

class _TopicSidebarState extends State<TopicSidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // 顶部：新建按钮
          _buildHeader(),
          
          // 搜索框
          _buildSearchBar(),
          
          // 话题列表
          Expanded(
            child: _buildTopicList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '对话',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onNewTopic,
            icon: const Icon(Icons.add),
            tooltip: '新对话',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '搜索对话...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTopicList() {
    final groups = widget.topicManager.groupByDate();
    final filteredGroups = <String, List<ConversationTopic>>{};

    // 过滤搜索结果
    groups.forEach((key, topics) {
      final filtered = _searchQuery.isEmpty
          ? topics
          : topics.where((t) {
              final query = _searchQuery.toLowerCase();
              return t.title.toLowerCase().contains(query) ||
                  t.summary.toLowerCase().contains(query) ||
                  t.keywords.any((k) => k.toLowerCase().contains(query));
            }).toList();
      if (filtered.isNotEmpty) {
        filteredGroups[key] = filtered;
      }
    });

    if (filteredGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '暂无对话' : '未找到匹配的对话',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (final entry in filteredGroups.entries) ...[
          // 分组标题
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 话题列表
          ...entry.value.map((topic) => _buildTopicItem(topic)),
        ],
      ],
    );
  }

  Widget _buildTopicItem(ConversationTopic topic) {
    final isCurrent = widget.topicManager.currentTopic?.id == topic.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTopicSelected(topic),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 话题图标
              Icon(
                _getTopicIcon(topic),
                size: 18,
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 12),
              // 话题信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (topic.summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        topic.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 更多操作
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                onSelected: (value) => _handleAction(topic, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('重命名'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('归档'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTopicIcon(ConversationTopic topic) {
    // 根据关键词判断图标
    final keywords = topic.keywords.map((k) => k.toLowerCase()).join(' ');
    
    if (keywords.contains('代码') || keywords.contains('code') || keywords.contains('编程')) {
      return Icons.code;
    }
    if (keywords.contains('翻译') || keywords.contains('translate')) {
      return Icons.translate;
    }
    if (keywords.contains('天气') || keywords.contains('weather')) {
      return Icons.wb_sunny_outlined;
    }
    if (keywords.contains('写作') || keywords.contains('write')) {
      return Icons.edit_note;
    }
    if (keywords.contains('学习') || keywords.contains('learn')) {
      return Icons.school_outlined;
    }
    
    return Icons.chat_bubble_outline;
  }

  void _handleAction(ConversationTopic topic, String action) {
    switch (action) {
      case 'rename':
        _showRenameDialog(topic);
        break;
      case 'archive':
        widget.topicManager.archiveTopic(topic.id);
        break;
      case 'delete':
        _showDeleteConfirm(topic);
        break;
    }
  }

  void _showRenameDialog(ConversationTopic topic) {
    final controller = TextEditingController(text: topic.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
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
              widget.topicManager.updateTopicTitle(topic.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(ConversationTopic topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除 "${topic.displayTitle}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              widget.topicManager.deleteTopic(topic.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

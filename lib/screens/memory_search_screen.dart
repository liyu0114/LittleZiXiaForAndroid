// Memory 搜索屏幕
//
// 搜索和浏览保存的记忆

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/memory/memory_service.dart';

class MemorySearchScreen extends StatefulWidget {
  const MemorySearchScreen({super.key});

  @override
  State<MemorySearchScreen> createState() => _MemorySearchScreenState();
}

class _MemorySearchScreenState extends State<MemorySearchScreen> {
  final _searchController = TextEditingController();
  final _addController = TextEditingController();
  List<MemorySearchResult> _results = [];
  List<MemoryEntry> _allEntries = [];
  bool _isSearching = false;
  bool _showAddDialog = false;

  @override
  void initState() {
    super.initState();
    _loadAllEntries();
  }

  Future<void> _loadAllEntries() async {
    final appState = context.read<AppState>();
    // 加载所有记忆条目
    // final entries = await appState.memoryService.getAll();
    // setState(() => _allEntries = entries);
    setState(() => _allEntries = []); // 暂时为空
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    // 模拟搜索延迟
    await Future.delayed(const Duration(milliseconds: 300));

    final appState = context.read<AppState>();
    // 这里需要访问 MemoryService
    // final results = appState.memoryService.search(query);
    
    setState(() {
      _isSearching = false;
      // _results = results;
      _results = []; // 暂时为空
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory 搜索'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索记忆...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          // 搜索按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 搜索结果
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _buildEmptyState()
                    : _buildResultsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMemory,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '搜索你的记忆',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入关键词搜索保存的内容',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(
              result.entry.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '相关度: ${(result.score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Text(
              _formatTime(result.entry.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            onTap: () => _showDetail(result),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 365) {
      return '${diff.inDays ~/ 365} 年前';
    } else if (diff.inDays > 30) {
      return '${diff.inDays ~/ 30} 个月前';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} 天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} 小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }

  void _showDetail(MemorySearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记忆详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '时间: ${result.entry.timestamp}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(result.entry.content),
              if (result.entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: result.entry.tags
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ],
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

  void _addMemory() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加记忆'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '输入要记住的内容...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // final appState = context.read<AppState>();
                // await appState.memoryService.add(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已添加到记忆')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

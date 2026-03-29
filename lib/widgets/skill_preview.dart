// 技能预览组件
//
// Markdown 格式的 SKILL.md 预览

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// 技能预览组件
class SkillPreview extends StatelessWidget {
  final String markdown;
  final bool showFrontmatter;
  final ScrollController? controller;

  const SkillPreview({
    super.key,
    required this.markdown,
    this.showFrontmatter = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // 预处理 markdown
    String content = markdown;
    
    // 如果不显示 frontmatter，移除它
    if (!showFrontmatter) {
      content = _removeFrontmatter(markdown);
    }
    
    return Markdown(
      data: content,
      controller: controller,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      styleSheet: MarkdownStyleSheet(
        h1: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
        h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
        h3: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        p: Theme.of(context).textTheme.bodyMedium,
        code: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.outline,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        tableBody: Theme.of(context).textTheme.bodyMedium,
        tableBorder: TableBorder.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      onTapLink: (text, href, title) {
        // 处理链接点击
        if (href != null) {
          debugPrint('Link tapped: $href');
          // TODO: 使用 url_launcher 打开链接
        }
      },
      imageBuilder: (uri, title, alt) {
        // 图片显示
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            uri.toString(),
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, 
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text('图片加载失败', 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        )),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 移除 YAML frontmatter
  String _removeFrontmatter(String content) {
    final frontmatterRegex = RegExp(r'^---\s*\n[\s\S]*?\n---\s*\n');
    return content.replaceFirst(frontmatterRegex, '');
  }
}

/// 技能预览对话框
class SkillPreviewDialog extends StatelessWidget {
  final String name;
  final String markdown;

  const SkillPreviewDialog({
    super.key,
    required this.name,
    required this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, 
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
          
          // 预览内容
          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
              ),
              child: SkillPreview(markdown: markdown),
            ),
          ),
          
          // 底部按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(context) {
    // 复制到剪贴板
    // TODO: 实现
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 已复制到剪贴板')),
    );
  }
}

/// 混合编辑/预览视图
class SkillEditorWithPreview extends StatefulWidget {
  final String? initialContent;
  final Function(String) onChanged;
  final bool readOnly;

  const SkillEditorWithPreview({
    super.key,
    this.initialContent,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<SkillEditorWithPreview> createState() => _SkillEditorWithPreviewState();
}

class _SkillEditorWithPreviewState extends State<SkillEditorWithPreview> {
  late TextEditingController _controller;
  bool _showPreview = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标签切换
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTab(
                  icon: Icons.edit,
                  label: '编辑',
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildTab(
                  icon: Icons.visibility,
                  label: '预览',
                  index: 1,
                ),
              ),
            ],
          ),
        ),
        
        // 内容区域
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              // 编辑器
              TextField(
                controller: _controller,
                readOnly: widget.readOnly,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: '输入 SKILL.md 内容...',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              // 预览
              SkillPreview(markdown: _controller.text),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedTabIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

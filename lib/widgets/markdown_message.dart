// Markdown 消息渲染组件
//
// 支持 LLM 回复中的 Markdown 格式渲染
// - 代码块高亮 + 复制按钮
// - 加粗、斜体、列表、链接等
// - 表格渲染
// - 流式输出时的打字机效果

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownMessageContent extends StatelessWidget {
  final String content;
  final bool isStreaming;
  final Color? textColor;

  const MarkdownMessageContent({
    super.key,
    required this.content,
    this.isStreaming = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      if (isStreaming) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('思考中...',
                style: TextStyle(fontSize: 15, color: textColor)),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownBody(
          data: content,
          selectable: true,
          builders: {
            'code': _CodeBlockBuilder(),
            'pre': _PreBlockBuilder(),
          },
          extensionSet: md.ExtensionSet.gitHubWeb,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 15, color: textColor, height: 1.5),
            h1: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            h2: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            h3: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            h4: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            code: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              backgroundColor: Colors.grey.shade200,
              color: Colors.red.shade700,
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockquote: TextStyle(
                fontSize: 15,
                color: textColor?.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic),
            blockquoteDecoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border(
                  left: BorderSide(color: Colors.grey.shade400, width: 3)),
            ),
            blockquotePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            listBullet: TextStyle(fontSize: 15, color: textColor),
            tableHead: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold),
            tableBody: const TextStyle(fontSize: 13),
            tableBorder: TableBorder.all(
                color: Colors.grey.shade300, width: 0.5),
            tableHeadAlign: TextAlign.center,
            a: const TextStyle(
              fontSize: 15,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            em: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: textColor),
            strong: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor),
          ),
        ),
        if (isStreaming) ...[
          const SizedBox(height: 4),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}

/// 代码块（围栏代码）Builder - 带复制按钮
class _PreBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    final code = element.textContent;
    // 尝试从子元素获取语言标签
    String language = '';
    if (element.children != null && element.children!.isNotEmpty) {
      final first = element.children!.first;
      if (first is md.Element && first.attributes.containsKey('class')) {
        language = first.attributes['class']?.replaceFirst('language-', '') ?? '';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部栏：语言标签 + 复制按钮
          if (language.isNotEmpty || true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.isEmpty ? 'code' : language,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  _CopyButton(text: code),
                ],
              ),
            ),
          // 代码内容
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 行内代码 Builder
class _CodeBlockBuilder extends MarkdownElementBuilder {
  // 行内代码由 styleSheet.code 处理即可
}

/// 复制按钮
class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check : Icons.copy,
              size: 14,
              color: _copied ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              _copied ? '已复制' : '复制',
              style: TextStyle(
                fontSize: 12,
                color: _copied ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 消息气泡长按菜单
void showMessageContextMenu(BuildContext context, String content) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('复制全部'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 分享功能
            },
          ),
        ],
      ),
    ),
  );
}

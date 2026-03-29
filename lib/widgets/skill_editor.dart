// Markdown 技能编辑器
//
// 支持语法高亮的 SKILL.md 编辑器

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' as highlight;

/// 语法高亮主题
class SkillEditorTheme {
  final Color backgroundColor;
  final Color textColor;
  final Color keywordColor;
  final Color stringColor;
  final Color commentColor;
  final Color numberColor;
  final Color punctuationColor;
  final Color headerColor;
  final Color linkColor;

  const SkillEditorTheme({
    required this.backgroundColor,
    required this.textColor,
    required this.keywordColor,
    required this.stringColor,
    required this.commentColor,
    required this.numberColor,
    required this.punctuationColor,
    required this.headerColor,
    required this.linkColor,
  });

  /// 深色主题
  static const dark = SkillEditorTheme(
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFD4D4D4),
    keywordColor: Color(0xFF569CD6),
    stringColor: Color(0xFFCE9178),
    commentColor: Color(0xFF6A9955),
    numberColor: Color(0xFFB5CEA8),
    punctuationColor: Color(0xFF808080),
    headerColor: Color(0xFF4EC9B0),
    linkColor: Color(0xFF6A9FB5),
  );

  /// 浅色主题
  static const light = SkillEditorTheme(
    backgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF383A42),
    keywordColor: Color(0xFFA626A4),
    stringColor: Color(0xFF50A14F),
    commentColor: Color(0xFFA0A1A7),
    numberColor: Color(0xFF986801),
    punctuationColor: Color(0xFF383A42),
    headerColor: Color(0xFF4078F2),
    linkColor: Color(0xFF0184BC),
  );
}

/// Markdown 技能编辑器
class SkillEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String) onChanged;
  final bool readOnly;
  final SkillEditorTheme? theme;
  final int minLines;
  final int maxLines;
  final String? hintText;
  final ScrollController? scrollController;

  const SkillEditor({
    super.key,
    this.initialContent,
    required this.onChanged,
    this.readOnly = false,
    this.theme,
    this.minLines = 10,
    this.maxLines = 500,
    this.hintText,
    this.scrollController,
  });

  @override
  State<SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<SkillEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final Map<int, TextSpan> _highlightCache = {};
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _lastText = _controller.text;
  }

  @override
  void didUpdateWidget(SkillEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContent != oldWidget.initialContent &&
        widget.initialContent != _controller.text) {
      _controller.text = widget.initialContent ?? '';
      _invalidateCache();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text != _lastText) {
      _lastText = text;
      widget.onChanged(text);
      // 增量更新缓存
      _incrementalUpdateCache(text);
    }
  }

  void _invalidateCache() {
    _highlightCache.clear();
    if (mounted) setState(() {});
  }

  void _incrementalUpdateCache(String text) {
    // 简单的缓存失效策略：文本长度变化超过 50 字符时重建
    if ((text.length - _lastText.length).abs() > 50) {
      _invalidateCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? SkillEditorTheme.dark 
            : SkillEditorTheme.light);

    return Stack(
      children: [
        // 语法高亮层（只读）
        _buildHighlightLayer(theme),
        
        // 输入层（透明）
        _buildInputLayer(theme),
      ],
    );
  }

  Widget _buildHighlightLayer(SkillEditorTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border.all(
          color: _focusNode.hasFocus 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: _buildHighlightedText(theme),
      ),
    );
  }

  Widget _buildHighlightedText(SkillEditorTheme theme) {
    final text = _controller.text;
    
    if (text.isEmpty) {
      return Text(
        widget.hintText ?? '输入 SKILL.md 内容...',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      );
    }

    // 解析并高亮
    final spans = _highlightMarkdown(text, theme);
    
    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: theme.textColor,
        ),
      ),
    );
  }

  List<InlineSpan> _highlightMarkdown(String text, SkillEditorTheme theme) {
    final spans = <InlineSpan>[];
    
    try {
      // 使用 highlight 库解析
      final result = highlight.highlight.parse(text, language: 'markdown');
      
      for (final node in result.nodes ?? <highlight.Node>[]) {
        _renderNode(node, spans, theme);
      }
    } catch (e) {
      // 解析失败，返回纯文本
      spans.add(TextSpan(text: text));
    }
    
    return spans;
  }

  void _renderNode(dynamic node, List<InlineSpan> spans, SkillEditorTheme theme) {
    if (node.className == 'text' || node.className == null && node.data != null) {
      // Text node
      spans.add(TextSpan(text: node.data?.toString() ?? ''));
    } else if (node.children != null) {
      // Element node
      final children = <InlineSpan>[];
      
      for (final child in node.children ?? <dynamic>[]) {
        _renderNode(child, children, theme);
      }
      
      // 根据 className 应用样式
      final style = _getStyleForClassName(node.className?.toString(), theme);
      
      spans.add(TextSpan(
        children: children,
        style: style,
      ));
    }
  }

  TextStyle? _getStyleForClassName(String? className, SkillEditorTheme theme) {
    if (className == null) return null;
    
    switch (className) {
      // Markdown 特定样式
      case 'title':
      case 'header':
        return TextStyle(
          color: theme.headerColor,
          fontWeight: FontWeight.bold,
        );
      case 'link':
        return TextStyle(
          color: theme.linkColor,
          decoration: TextDecoration.underline,
        );
      case 'strong':
        return TextStyle(
          fontWeight: FontWeight.bold,
        );
      case 'emphasis':
        return TextStyle(
          fontStyle: FontStyle.italic,
        );
      case 'code':
      case 'codeblock':
        return TextStyle(
          backgroundColor: theme.backgroundColor.withOpacity(0.5),
          fontFamily: 'monospace',
        );
      case 'blockquote':
        return TextStyle(
          color: theme.commentColor,
          fontStyle: FontStyle.italic,
        );
      
      // YAML frontmatter 样式
      case 'attr':
      case 'attribute':
        return TextStyle(color: theme.keywordColor);
      case 'string':
        return TextStyle(color: theme.stringColor);
      case 'number':
        return TextStyle(color: theme.numberColor);
      case 'comment':
        return TextStyle(
          color: theme.commentColor,
          fontStyle: FontStyle.italic,
        );
      case 'punctuation':
        return TextStyle(color: theme.punctuationColor);
      
      default:
        return null;
    }
  }

  Widget _buildInputLayer(SkillEditorTheme theme) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Colors.transparent, // 文字透明，只保留光标
      ),
      cursorColor: theme.textColor,
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(12),
        fillColor: Colors.transparent,
        filled: true,
      ),
      scrollController: widget.scrollController,
      contextMenuBuilder: (context, state) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: state,
        );
      },
    );
  }
}

/// 简化版的语法高亮（不依赖 highlight 库）
class SimpleSkillEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String) onChanged;
  final bool readOnly;
  final int minLines;
  final int maxLines;
  final String? hintText;

  const SimpleSkillEditor({
    super.key,
    this.initialContent,
    required this.onChanged,
    this.readOnly = false,
    this.minLines = 10,
    this.maxLines = 500,
    this.hintText,
  });

  @override
  State<SimpleSkillEditor> createState() => _SimpleSkillEditorState();
}

class _SimpleSkillEditorState extends State<SimpleSkillEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(SimpleSkillEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContent != oldWidget.initialContent &&
        widget.initialContent != _controller.text) {
      _controller.text = widget.initialContent ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText ?? '输入 SKILL.md 内容...',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

/// 带行号的编辑器包装
class SkillEditorWithLineNumbers extends StatelessWidget {
  final String? initialContent;
  final Function(String) onChanged;
  final bool readOnly;

  const SkillEditorWithLineNumbers({
    super.key,
    this.initialContent,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行号
            _buildLineNumbers(constraints),
            
            // 编辑器
            Expanded(
              child: SimpleSkillEditor(
                initialContent: initialContent,
                onChanged: onChanged,
                readOnly: readOnly,
                minLines: 10,
                maxLines: 500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineNumbers(BoxConstraints constraints) {
    final lines = (initialContent ?? '').split('\n').length;
    
    return Container(
      width: 40,
      padding: const EdgeInsets.only(top: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          lines.clamp(10, 500),
          (i) => Text(
            '${i + 1}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

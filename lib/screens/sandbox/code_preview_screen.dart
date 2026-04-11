// 代码沙盒 UI - WebView 运行器
//
// 展示和运行代码项目
// 支持代码查看、实时预览、编辑

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/sandbox/code_sandbox_service.dart';

/// 代码预览页面（WebView 运行）
class CodePreviewScreen extends StatefulWidget {
  final CodeProject project;

  const CodePreviewScreen({super.key, required this.project});

  @override
  State<CodePreviewScreen> createState() => _CodePreviewScreenState();
}

class _CodePreviewScreenState extends State<CodePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WebViewController _webViewController;
  String _selectedFile = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.project.files.containsKey('index.html')) {
      _selectedFile = 'index.html';
    } else if (widget.project.files.isNotEmpty) {
      _selectedFile = widget.project.files.keys.first;
    }
    _initWebView();
  }

  void _initWebView() {
    final html = widget.project.fullHtml;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadHtmlString(html);
  }

  void _reload() {
    setState(() => _isLoading = true);
    final html = widget.project.fullHtml;
    _webViewController.loadHtmlString(html);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: '重新运行',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle), text: '预览'),
            Tab(icon: Icon(Icons.code), text: '代码'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 预览 Tab
          Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),

          // 代码 Tab
          _buildCodeView(),
        ],
      ),
    );
  }

  Widget _buildCodeView() {
    final files = widget.project.files;
    if (files.isEmpty) {
      return const Center(child: Text('没有文件'));
    }

    return Column(
      children: [
        // 文件选择器
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: files.keys.map((filename) {
              final isSelected = filename == _selectedFile;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(filename),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedFile = filename);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // 代码内容
        Expanded(
          child: _selectedFile.isNotEmpty && files.containsKey(_selectedFile)
              ? _CodeView(content: files[_selectedFile]!)
              : const Center(child: Text('选择一个文件查看')),
        ),
      ],
    );
  }
}

/// 代码显示组件（语法高亮用主题色模拟）
class _CodeView extends StatelessWidget {
  final String content;

  const _CodeView({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFFD4D4D4),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// 代码沙盒 UI - WebView 运行器
//
// 展示和运行代码项目
// 支持代码查看、实时预览、编辑、通过对话修改

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/sandbox/code_sandbox_service.dart';
import '../../providers/app_state.dart';

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
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _editController = TextEditingController();
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

  void _startEditing() {
    final content = widget.project.files[_selectedFile] ?? '';
    _editController.text = content;
    setState(() => _isEditing = true);
  }

  void _saveEdit() {
    final sandbox = CodeSandboxService();
    sandbox.updateProjectFile(widget.project.id, _selectedFile, _editController.text);
    setState(() => _isEditing = false);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 代码已保存并重新运行')),
    );
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  /// 通过对话修改代码 - 跳转到主聊天页面并发送修改指令
  void _chatToModify() {
    final project = widget.project;
    final filesSummary = project.files.entries.map((e) {
      final preview = e.value.length > 200
          ? '${e.value.substring(0, 200)}...'
          : e.value;
      return '【${e.key}】\n$preview';
    }).join('\n\n');

    final message = '请帮我修改代码项目"${project.name}"。'
        '\n\n当前代码：\n$filesSummary';

    // 返回到首页
    Navigator.popUntil(context, (route) => route.isFirst);
    
    // 通过 AppState 设置待发送消息
    final appState = context.read<AppState>();
    appState.setPendingMessage(message);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          // 编辑按钮
          if (!_isEditing && _tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _startEditing,
              tooltip: '编辑代码',
            ),
          // 对话改代码按钮
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _chatToModify,
            tooltip: '通过对话修改',
          ),
          // 刷新按钮
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
          _isEditing ? _buildEditView() : _buildCodeView(),
        ],
      ),
      // 编辑模式下的底部操作栏
      bottomNavigationBar: _isEditing
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveEdit,
                      icon: const Icon(Icons.save),
                      label: const Text('保存并运行'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
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

        // 底部提示
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💡 点击右上角 ✏️ 编辑代码，或 💬 通过对话让小紫霞帮你改',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditView() {
    return Column(
      children: [
        // 文件名显示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.edit_document, size: 16),
              const SizedBox(width: 8),
              Text(
                '编辑: $_selectedFile',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // 编辑器
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: TextField(
              controller: _editController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFD4D4D4),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
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

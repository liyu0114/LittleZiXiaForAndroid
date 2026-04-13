import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';
import 'agent_progress.dart';
import 'markdown_message.dart';

class MessageList extends StatefulWidget {
  final List<ConversationMessage> messages;

  const MessageList({
    super.key,
    required this.messages,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolling = false;
  bool _isNearBottom = true;  // 是否接近底部
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    // 检测用户是否在手动滚动
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      // 如果距离底部不超过 100 像素，认为"接近底部"
      _isNearBottom = (maxScroll - currentScroll) < 100;
      
      // 检测用户是否在手动滚动（非程序触发的滚动）
      if (_scrollController.position.isScrollingNotifier.value) {
        _isUserScrolling = true;
      }
    }
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当消息数量变化时，只有在接近底部时才自动滚动
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottomIfNeeded();
    }
    
    // 当最后一条消息内容变化（流式输出），如果接近底部则滚动
    if (widget.messages.isNotEmpty && 
        oldWidget.messages.isNotEmpty &&
        widget.messages.last.id == oldWidget.messages.last.id &&
        widget.messages.last.content != oldWidget.messages.last.content) {
      _scrollToBottomIfNeeded();
    }
  }
  
  void _scrollToBottomIfNeeded() {
    if (!_isNearBottom) return;  // 用户在查看历史，不滚动
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  /// 手动滚动到底部
  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final message = widget.messages[index];
            return _MessageBubble(message: message);
          },
        ),
        
        // "滚动到底部"按钮（当用户向上滚动时显示）
        if (!_isNearBottom && _scrollController.hasClients)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                scrollToBottom();
                setState(() {
                  _isNearBottom = true;
                });
              },
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const _MessageBubble({required this.message});

  /// 判断是否只是状态消息（如"正在思考..."），不需要单独显示
  bool _isOnlyStatusMessage(String content) {
    final statusMessages = [
      '🤔 正在分析任务...',
      '🧩 正在分解任务...',
      '🔄 任务分解失败，直接执行...',
    ];
    return statusMessages.contains(content) || 
           content.startsWith('⚡ 执行:') ||
           content.startsWith('📊 进度:') ||
           content.startsWith('🔁');
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isStreaming = message.isStreaming;
    final hasError = message.error != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple.shade100,
              child: const Text('💜', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                if (message.content.isNotEmpty) {
                  showMessageContextMenu(context, message.content);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : hasError
                          ? Colors.red.shade50
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: hasError
                      ? Border.all(color: Colors.red.shade200)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasError) ...[
                      Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '错误',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Agent 步骤进度（如果有）
                    if (message.isAgentMessage)
                      AgentProgressWidget(
                        steps: message.agentSteps,
                        currentMessage: message.content,
                      ),

                    // Agent 进度消息 or 普通内容之间有分隔
                    if (message.isAgentMessage && message.content.isNotEmpty && !_isOnlyStatusMessage(message.content))
                      const Divider(height: 16),

                    // 显示图片
                    if (message.hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 200,
                            maxHeight: 200,
                          ),
                          child: Image.file(
                            File(message.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 显示视频
                    if (message.hasVideo) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, size: 24),
                            SizedBox(width: 8),
                            Text('视频文件'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 显示文件
                    if (message.hasFile) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.fileName ?? '文件',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (message.fileSize != null)
                                    Text(
                                      '${(message.fileSize! / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 显示文字（用户纯文本，助手 Markdown 渲染）
                    if (message.content.isNotEmpty || isStreaming)
                      isUser
                          ? SelectableText(
                              message.content,
                              style: const TextStyle(fontSize: 15),
                            )
                          : MarkdownMessageContent(
                              content: message.content,
                              isStreaming: isStreaming,
                              textColor:
                                  hasError ? Colors.red.shade900 : null,
                            ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

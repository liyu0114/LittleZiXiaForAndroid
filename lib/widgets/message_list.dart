import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import '../services/llm/llm_base.dart';

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

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当消息数量变化时，自动滚动到底部
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const _MessageBubble({required this.message});

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
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : hasError
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: hasError ? Border.all(color: Colors.red.shade200) : null,
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
                  SelectableText(
                    message.content.isEmpty && isStreaming
                        ? '思考中...'
                        : message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: hasError ? Colors.red.shade900 : null,
                    ),
                  ),
                  if (isStreaming && message.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
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

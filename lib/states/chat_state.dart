import 'dart:convert';

/// 聊天状态管理
class ChatState {
  final List messages;
  final int messageIndex;
  final String? currentSession;
  
  ChatState({
    required this.messages,
    this.messageIndex = 0,
    this.currentSession,
  });
}

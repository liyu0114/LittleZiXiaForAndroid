// 群聊入口界面 - 使用统一的房间系统
//
// 统一UI：单机模式 + 联网模式

import 'package:flutter/material.dart';
import '../widgets/room_entry_screen.dart';
import 'group_chat_screen.dart';
import 'network_chat_screen.dart';

class GroupChatEntryScreen extends StatelessWidget {
  const GroupChatEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoomEntryScreen(
      title: '群聊',
      icon: Icons.chat,
      singlePlayerScreen: () => const GroupChatScreen(),
      networkScreen: () => const NetworkChatScreen(),
    );
  }
}


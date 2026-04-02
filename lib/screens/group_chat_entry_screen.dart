// 群聊入口界面 - 和24点入口统一
//
// 设计：
// - 单机群聊 → 原有的群聊界面
// - 联网群聊 → 新的联网群聊界面

import 'package:flutter/material.dart';
import 'group_chat_screen.dart';
import 'network_chat_screen.dart';

class GroupChatEntryScreen extends StatelessWidget {
  const GroupChatEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('群聊', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                '单机群聊 或 通过 Tailscale 联网',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GroupChatScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('单机群聊'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NetworkChatScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.wifi),
                label: const Text('联网群聊'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 单机群聊屏幕
//
// 对话页的扩展版：用户 + 多个机器人
// 完全本地化，不需要网络

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/chat/chat_bot_service.dart';

/// 群聊消息
class LocalChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime time;
  final bool isBot;
  
  LocalChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.time,
    this.isBot = false,
  });
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  // 消息列表
  final List<LocalChatMessage> _messages = [];
  final _messageController = TextEditingController();
  
  // 用户信息
  late String _localUserId;
  final String _localUserName = '我';
  
  // 机器人列表
  final List<ChatBotService> _bots = [];
  
  // 是否已初始化
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _localUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    _initServices();
  }
  
  void _initServices() async {
    setState(() => _initialized = true);
    
    // 默认添加一个小紫霞机器人
    _addBot();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    for (final bot in _bots) {
      bot.dispose();
    }
    super.dispose();
  }
  
  /// 添加机器人
  void _addBot() {
    final appState = context.read<AppState>();
    
    final bot = ChatBotService(
      skillExecuteCallback: (skillId, params) async {
        try {
          debugPrint('[GroupChat] 执行技能: $skillId, params: $params');
          final result = await appState.executeSkill(skillId, params);
          debugPrint('[GroupChat] 技能结果: $result');
          return result;
        } catch (e) {
          debugPrint('[GroupChat] 技能执行失败: $e');
          return null;
        }
      },
      config: BotConfig.defaultBot(),
      replyProbability: 0.15,  // 降低随机回复概率到 15%
      minReplyDelay: 2000,
      maxReplyDelay: 5000,
    );
    
    setState(() {
      _bots.add(bot);
    });
    
    // 机器人发送欢迎消息
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _addBotMessage(bot, '大家好！我是${bot.botName}，很高兴加入群聊~');
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ 机器人 ${bot.botName} 已加入群聊')),
    );
  }
  
  /// 添加机器人消息
  void _addBotMessage(ChatBotService bot, String content) {
    final message = LocalChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: bot.botId,
      senderName: bot.botName,
      content: content,
      time: DateTime.now(),
      isBot: true,
    );
    
    setState(() {
      _messages.add(message);
    });
    
    // 添加到所有机器人的历史
    for (final b in _bots) {
      b.addToHistory(bot.botId, bot.botName, content);
    }
  }
  
  /// 发送消息
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    // 添加用户消息
    final message = LocalChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _localUserId,
      senderName: _localUserName,
      content: content,
      time: DateTime.now(),
    );
    
    setState(() {
      _messages.add(message);
    });
    
    // 添加到所有机器人的历史
    for (final bot in _bots) {
      bot.addToHistory(_localUserId, _localUserName, content);
    }
    
    _messageController.clear();
    
    // 让机器人决定是否回复
    _handleBotReplies(content);
  }
  
  /// 处理机器人回复
  void _handleBotReplies(String content) {
    for (final bot in _bots) {
      if (bot.shouldReply(content, _localUserId)) {
        // 延迟回复（模拟思考）
        Future.delayed(bot.getReplyDelay(), () async {
          if (!mounted) return;
          
          final reply = await bot.generateReply(content, _localUserName);
          if (reply != null && reply.isNotEmpty) {
            _addBotMessage(bot, reply);
          }
        });
      }
    }
  }
  
  /// 清空聊天记录
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                for (final bot in _bots) {
                  bot.clearHistory();
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 聊天记录已清空')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示机器人列表
  void _showBotList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('机器人列表', style: Theme.of(context).textTheme.titleLarge),
                Text('${_bots.length} 个机器人'),
              ],
            ),
            const SizedBox(height: 16),
            if (_bots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无机器人', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: _bots.length,
                itemBuilder: (context, index) {
                  final bot = _bots[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: const Icon(Icons.smart_toy, color: Colors.purple),
                    ),
                    title: Text(bot.botName),
                    subtitle: const Text('小紫霞 AI 助手'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _bots.removeAt(index);
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ 机器人 ${bot.botName} 已移除')),
                        );
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _addBot();
                },
                icon: const Icon(Icons.add),
                label: const Text('添加机器人'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单机群聊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            onPressed: _showBotList,
            tooltip: '机器人列表',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBot,
            tooltip: '添加机器人',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('清空聊天记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 机器人数量提示
          if (_bots.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.purple.shade50,
              child: Row(
                children: [
                  Icon(Icons.smart_toy, size: 16, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${_bots.length} 个机器人在线',
                    style: TextStyle(color: Colors.purple.shade700),
                  ),
                ],
              ),
            ),
          
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '开始聊天吧！',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '已添加 ${_bots.length} 个机器人',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == _localUserId;
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? Theme.of(context).colorScheme.primaryContainer
                                : msg.isBot
                                    ? Colors.purple.shade50
                                    : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.isBot)
                                      Icon(Icons.smart_toy, size: 14, color: Colors.purple.shade700)
                                    else
                                      Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      msg.senderName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: msg.isBot ? Colors.purple.shade700 : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              Text(msg.content),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // 输入框
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

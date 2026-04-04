// 联网群聊屏幕 - 和24点联网游戏统一
//
// 架构说明：
// - 主机：创建房间，等待玩家加入，点击"开始群聊"
// - 客户端：通过IP加入房间，等待主机开始
// - 机器人：主机可以添加 AI 机器人参与对话

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat/group_chat_service.dart';
import '../services/chat/p2p_messaging.dart';
import '../services/chat/chat_bot_service.dart';
import '../providers/app_state.dart';

class NetworkChatScreen extends StatefulWidget {
  const NetworkChatScreen({super.key});

  @override
  State<NetworkChatScreen> createState() => _NetworkChatScreenState();
}

class _NetworkChatScreenState extends State<NetworkChatScreen> {
  // 网络服务
  P2PMessagingService? _networkService;
  
  // 群聊服务
  GroupChatService? _chatService;
  
  // 机器人服务
  ChatBotService? _botService;
  bool _botEnabled = true;  // 默认启用机器人
  
  // 网络状态
  bool _isHost = false;
  bool _isConnected = false;
  
  // 本地玩家信息
  String? _localUserId;
  String _localUserName = '用户';
  
  // 房间状态
  String? _roomId;
  String _roomName = '';
  List<Map<String, dynamic>> _players = [];
  bool _chatStarted = false;
  
  // 消息
  List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _chatService?.dispose();
    _networkService?.dispose();
    _botService?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// 创建房间（成为主机）
  void _createRoom(String roomName) async {
    _isHost = true;
    _isConnected = true;
    _roomName = roomName;
    
    // 初始化网络服务
    _networkService = P2PMessagingService();
    await _networkService!.init(
      deviceId: _localUserId!,
      deviceName: _localUserName,
      port: 18792,  // 群聊用不同端口
    );
    
    // 初始化群聊服务
    _chatService = GroupChatService();
    await _chatService!.initUser(
      userId: _localUserId!,
      userName: _localUserName,
      isBot: false,
    );
    
    // 初始化机器人服务（如果启用）
    if (_botEnabled) {
      try {
        final appState = context.read<AppState>();
        _botService = ChatBotService(
          config: BotConfig.defaultBot(),
          replyProbability: 0.2,  // 20% 概率随机回复
        );
        debugPrint('[NetworkChat] 机器人服务已初始化');
      } catch (e) {
        debugPrint('[NetworkChat] 机器人服务初始化失败: $e');
      }
    }
    
    // 创建房间
    final room = _chatService!.createRoom(roomName);
    _roomId = room.id;
    
    // 监听网络消息
    _networkService!.messageStream.listen((message) {
      _handleNetworkMessage(message);
    });
    
    // 监听新连接
    _networkService!.connectionStream.listen((connection) {
      setState(() {
        _players.add({
          'id': connection.deviceId,
          'name': connection.deviceName,
          'isHost': false,
        });
      });
      _broadcastPlayerList();
    });
    
    setState(() {
      _players = [
        {'id': _localUserId, 'name': _localUserName, 'isHost': true},
      ];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('房间已创建，等待其他用户加入...')),
    );
  }

  /// 加入房间（成为客户端）
  void _joinRoom(String hostIp) async {
    _isHost = false;
    
    _networkService = P2PMessagingService();
    await _networkService!.init(
      deviceId: _localUserId!,
      deviceName: _localUserName,
      port: 18793,  // 客户端用不同端口
    );
    
    final success = await _networkService!.connectToDevice(
      deviceId: 'host_$hostIp',
      deviceName: '主机',
      ipAddress: hostIp,
      port: 18792,
    );
    
    if (success) {
      setState(() {
        _isConnected = true;
      });
      
      // 监听网络消息
      _networkService!.messageStream.listen((message) {
        _handleNetworkMessage(message);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 $hostIp')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('连接失败')),
      );
    }
  }

  /// 处理网络消息
  void _handleNetworkMessage(P2PMessage message) {
    final payload = message.payload;
    final action = payload['action'];
    
    switch (action) {
      case 'playerList':
        setState(() {
          _players = List<Map<String, dynamic>>.from(payload['players']);
        });
        break;
        
      case 'chatStarted':
        setState(() {
          _chatStarted = true;
          _roomName = payload['roomName'];
        });
        break;
        
      case 'message':
        setState(() {
          _messages.add({
            'userId': message.fromId,
            'userName': message.fromName,
            'content': payload['content'],
            'time': DateTime.now(),
          });
        });
        
        // 主机处理机器人回复
        if (_isHost && _botEnabled) {
          _handleBotReply(payload['content'], message.fromId, message.fromName);
        }
        break;
    }
  }

  /// 广播玩家列表（主机）
  void _broadcastPlayerList() {
    if (!_isHost || _networkService == null) return;
    
    final message = P2PMessage(
      type: P2PMessageType.chatMessage,
      fromId: _localUserId!,
      fromName: _localUserName,
      payload: {'action': 'playerList', 'players': _players},
    );
    
    _networkService!.broadcast(message);
  }

  /// 添加机器人到群聊
  void _addBot() {
    // 如果机器人服务未创建，先创建
    if (_botService == null) {
      final appState = context.read<AppState>();
      _botService = ChatBotService(
        skillExecuteCallback: (skillId, params) async {
          try {
            return await appState.executeSkill(skillId, params);
          } catch (e) {
            debugPrint('[NetworkChat] 技能执行失败: $e');
            return null;
          }
        },
        config: BotConfig(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          name: '小紫霞',
        ),
      );
    }
    
    final botId = _botService!.botId;
    final botName = _botService!.botName;
    
    // 检查机器人是否已在玩家列表
    final botExists = _players.any((p) => p['id'] == botId);
    if (botExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 机器人已在群聊中')),
      );
      return;
    }
    
    setState(() {
      _players.add({
        'id': botId,
        'name': botName,
        'isHost': false,
        'isBot': true,
      });
    });
    
    // 如果是主机，广播更新
    if (_isHost && _networkService != null) {
      _broadcastPlayerList();
    }
    
    // 机器人发送欢迎消息
    Future.delayed(const Duration(milliseconds: 500), () {
      _sendBotWelcomeMessage();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ 机器人 $botName 已加入群聊')),
    );
  }
  
  /// 开始群聊（主机）
  void _startChat() {
    if (!_isHost) return;
    
    setState(() {
      _chatStarted = true;
    });
    
    // 添加机器人到玩家列表（如果启用）
    if (_botEnabled && _botService != null) {
      _players.add({
        'id': _botService!.botId,
        'name': _botService!.botName,
        'isHost': false,
        'isBot': true,
      });
      
      // 广播更新后的玩家列表
      _broadcastPlayerList();
    }
    
    // 通知所有客户端
    final message = P2PMessage(
      type: P2PMessageType.chatMessage,
      fromId: _localUserId!,
      fromName: _localUserName,
      payload: {
        'action': 'chatStarted',
        'roomName': _roomName,
        'botEnabled': _botEnabled,
        'botName': _botService?.botName ?? '小紫霞',
      },
    );
    
    _networkService?.broadcast(message);
    
    // 机器人发送欢迎消息
    if (_botEnabled) {
      _sendBotWelcomeMessage();
    }
  }
  
  /// 机器人发送欢迎消息
  void _sendBotWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final welcomeMessages = [
        '大家好！我是小紫霞，很高兴加入群聊~',
        '哈喽！群聊开始了，有什么想聊的吗？',
        '嗨大家！我是 AI 助手小紫霞，一起聊天吧~',
      ];
      
      final content = welcomeMessages[DateTime.now().millisecondsSinceEpoch % welcomeMessages.length];
      _sendBotMessage(content);
    });
  }
  
  /// 发送机器人消息
  void _sendBotMessage(String content) {
    if (_botService == null || _networkService == null) return;
    
    final message = P2PMessage(
      type: P2PMessageType.chatMessage,
      fromId: _botService!.botId,
      fromName: _botService!.botName,
      payload: {
        'action': 'message',
        'content': content,
      },
    );
    
    setState(() {
      _messages.add({
        'userId': _botService!.botId,
        'userName': _botService!.botName,
        'content': content,
        'time': DateTime.now(),
        'isBot': true,
      });
    });
    
    _networkService?.broadcast(message);
    _botService!.addToHistory(_botService!.botId, _botService!.botName, content);
  }
  
  /// 处理机器人回复（主机）
  void _handleBotReply(String messageContent, String senderId, String senderName) {
    if (_botService == null || !_isHost || senderId == _botService!.botId) return;
    
    // 添加到历史
    _botService!.addToHistory(senderId, senderName, messageContent);
    
    // 决定是否回复
    if (_botService!.shouldReply(messageContent, senderId)) {
      // 延迟回复（模拟思考）
      Future.delayed(_botService!.getReplyDelay(), () async {
        if (!mounted) return;
        
        final reply = await _botService!.generateReply(messageContent, senderName);
        if (reply != null && reply.isNotEmpty) {
          _sendBotMessage(reply);
        }
      });
    }
  }

  /// 发送消息
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    final message = P2PMessage(
      type: P2PMessageType.chatMessage,
      fromId: _localUserId!,
      fromName: _localUserName,
      payload: {
        'action': 'message',
        'content': content,
      },
    );
    
    setState(() {
      _messages.add({
        'userId': _localUserId,
        'userName': _localUserName,
        'content': content,
        'time': DateTime.now(),
      });
    });
    
    if (_isHost) {
      _networkService?.broadcast(message);
      
      // 主机处理机器人回复
      if (_botEnabled) {
        _handleBotReply(content, _localUserId!, _localUserName);
      }
    } else {
      // 客户端只连接到主机，发送到第一个连接
      final connections = _networkService?.connections ?? [];
      if (connections.isNotEmpty) {
        _networkService?.sendTo(connections.first.deviceId, message);
      }
    }
    
    _messageController.clear();
  }

  void _showJoinDialog() {
    final ipController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入房间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入主机的 IP 地址'),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: '主机 IP',
                hintText: '例如: 100.120.127.105',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context);
                _joinRoom(ip);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  /// 显示创建房间对话框
  void _showCreateRoomDialog() {
    final roomNameController = TextEditingController(text: '聊天室');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建房间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomNameController,
              decoration: const InputDecoration(
                labelText: '房间名称',
                hintText: '给你的房间起个名字',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _createRoom(roomNameController.text.trim().isEmpty 
                  ? '聊天室' 
                  : roomNameController.text.trim());
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chatStarted) {
      return _buildChatView();
    } else if (_isConnected) {
      return _buildWaitingRoom();
    } else {
      return _buildLobby();
    }
  }

  Widget _buildLobby() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联网群聊'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('联网群聊', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                '通过 Tailscale 与朋友一起聊天',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _showCreateRoomDialog,
                icon: const Icon(Icons.add),
                label: const Text('创建房间'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showJoinDialog,
                icon: const Icon(Icons.link),
                label: const Text('加入房间'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联网群聊'),
        actions: [
          if (_isConnected)
            Chip(
              label: Text(_isHost ? '主机' : '已连接'),
              backgroundColor: _isHost ? Colors.green : Colors.blue,
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showNameEditDialog,
            tooltip: '修改名字',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('房间: $_roomName', 
                             style: Theme.of(context).textTheme.titleLarge),
                        Chip(
                          label: Text('${_players.length}/10'),
                          backgroundColor: Colors.green.shade100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('我的名字: $_localUserName', 
                         style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('参与者', style: Theme.of(context).textTheme.titleMedium),
                Text('${_players.length} 人', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final player = _players[index];
                  final isMe = player['id'] == _localUserId;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                      child: Icon(
                        player['isHost'] 
                            ? Icons.star 
                            : player['isBot'] == true 
                                ? Icons.smart_toy 
                                : Icons.person,
                        color: player['isBot'] == true ? Colors.purple : null,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(player['name']),
                        if (player['isBot'] == true)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('机器人', style: TextStyle(fontSize: 10, color: Colors.purple)),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (player['isHost']) 
                          const Chip(label: Text('主机'), backgroundColor: Colors.green),
                        if (isMe) 
                          const Chip(label: Text('我'), backgroundColor: Colors.blue),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // 添加机器人按钮（主机和客户端都能添加）
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _addBot,
                icon: const Icon(Icons.smart_toy),
                label: const Text('添加机器人（小紫霞）'),
              ),
            ),
            const SizedBox(height: 8),
            // 开始群聊按钮（只有主机能点击）
            if (_isHost)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _players.length >= 1 ? _startChat : null,
                  icon: const Icon(Icons.chat),
                  label: const Text('开始群聊'),
                ),
              )
            else
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '等待主机开始群聊...',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 显示修改名字对话框
  void _showNameEditDialog() {
    final controller = TextEditingController(text: _localUserName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改名字'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '你的名字',
            hintText: '输入你在群聊中的名字',
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _localUserName = newName;
                });
                
                // 更新玩家列表中的名字
                final index = _players.indexWhere((p) => p['id'] == _localUserId);
                if (index >= 0) {
                  _players[index]['name'] = newName;
                }
                
                // 广播更新
                if (_isHost) {
                  _broadcastPlayerList();
                } else {
                  // 客户端通知主机
                  _networkService?.broadcast(P2PMessage(
                    type: P2PMessageType.chatMessage,
                    fromId: _localUserId!,
                    fromName: newName,
                    payload: {'action': 'updateName', 'newName': newName},
                  ));
                }
                
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomName),
        actions: [
          Chip(
            label: Text('${_players.length}人'),
            backgroundColor: Colors.green.shade100,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['userId'] == _localUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            msg['userName'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(msg['content']),
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
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
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

// 群聊服务
//
// 实现多个小紫霞机器人 + 用户群聊

import 'dart:async';
import 'package:logger/logger.dart';
import 'p2p_messaging.dart';
import '../llm/llm_base.dart';
import '../llm/llm_factory.dart';

/// 群聊房间
class ChatRoom {
  final String id;
  final String name;
  final List<String> members; // 用户ID列表
  final DateTime createdAt;
  final String? creatorId;

  ChatRoom({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    this.creatorId,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] ?? '',
      name: json['name'] ?? '未命名房间',
      members: List<String>.from(json['members'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      creatorId: json['creatorId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members,
    'createdAt': createdAt.toIso8601String(),
    'creatorId': creatorId,
  };
}

/// 群聊消息
class GroupChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isFromBot; // 是否来自机器人

  GroupChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isFromBot = false,
  });

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) {
    return GroupChatMessage(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '匿名',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isFromBot: json['isFromBot'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'senderId': senderId,
    'senderName': senderName,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isFromBot': isFromBot,
  };
}

/// 群聊服务
class GroupChatService {
  final Logger _logger = Logger();
  
  // 房间列表
  final Map<String, ChatRoom> _rooms = {};
  
  // 消息历史
  final Map<String, List<GroupChatMessage>> _messages = {};
  
  // 当前用户信息
  String? _currentUserId;
  String? _currentUserName;
  bool _isBot = false;
  
  // P2P 消息服务
  P2PMessagingService? _p2pService;
  
  // LLM 服务（用于机器人回复）
  LLMProvider? _llmProvider;
  
  // 机器人配置
  String _botSystemPrompt = '你是一个友好的小紫霞机器人，在群聊中与人交流。回复要简洁有趣。';
  bool _botAutoReply = true;
  
  // 流控制器
  final _messageController = StreamController<GroupChatMessage>.broadcast();
  final _roomController = StreamController<ChatRoom>.broadcast();
  
  /// 消息流
  Stream<GroupChatMessage> get messageStream => _messageController.stream;
  
  /// 房间变化流
  Stream<ChatRoom> get roomStream => _roomController.stream;
  
  /// 所有房间
  List<ChatRoom> get rooms => _rooms.values.toList();
  
  /// 当前用户ID
  String? get currentUserId => _currentUserId;
  
  /// P2P 服务
  P2PMessagingService? get p2pService => _p2pService;
  
  /// 初始化用户信息
  Future<void> initUser({
    required String userId,
    required String userName,
    bool isBot = false,
    int p2pPort = 18790,
    LLMProvider? llmProvider,
  }) async {
    _currentUserId = userId;
    _currentUserName = userName;
    _isBot = isBot;
    _llmProvider = llmProvider;
    
    _logger.i('群聊服务初始化: $userName (${isBot ? '机器人' : '用户'})');
    
    // 初始化 P2P 服务
    _p2pService = P2PMessagingService();
    await _p2pService!.init(
      deviceId: userId,
      deviceName: userName,
      port: p2pPort,
    );
    
    // 监听 P2P 消息
    _p2pService!.messageStream.listen(_handleP2PMessage);
  }
  
  /// 设置机器人配置
  void setBotConfig({
    String? systemPrompt,
    bool? autoReply,
  }) {
    if (systemPrompt != null) _botSystemPrompt = systemPrompt;
    if (autoReply != null) _botAutoReply = autoReply;
  }
  
  /// 创建房间
  ChatRoom createRoom(String name, {List<String>? initialMembers}) {
    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final members = <String>[_currentUserId!];
    if (initialMembers != null) {
      members.addAll(initialMembers);
    }
    
    final room = ChatRoom(
      id: roomId,
      name: name,
      members: members.toSet().toList(), // 去重
      createdAt: DateTime.now(),
      creatorId: _currentUserId,
    );
    
    _rooms[roomId] = room;
    _messages[roomId] = [];
    _roomController.add(room);
    
    _logger.i('创建房间: $name (${room.members.length}人)');
    return room;
  }
  
  /// 加入房间
  bool joinRoom(String roomId) {
    final room = _rooms[roomId];
    if (room == null) {
      _logger.w('房间不存在: $roomId');
      return false;
    }
    
    if (room.members.contains(_currentUserId)) {
      _logger.i('已在房间中: $roomId');
      return true;
    }
    
    room.members.add(_currentUserId!);
    _roomController.add(room);
    
    _logger.i('加入房间: $roomId');
    return true;
  }
  
  /// 离开房间
  bool leaveRoom(String roomId) {
    final room = _rooms[roomId];
    if (room == null) return false;
    
    room.members.remove(_currentUserId);
    _roomController.add(room);
    
    _logger.i('离开房间: $roomId');
    return true;
  }
  
  /// 发送消息
  void sendMessage(String roomId, String content) {
    if (_currentUserId == null) {
      _logger.e('未初始化用户信息');
      return;
    }
    
    final message = GroupChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: _currentUserId!,
      senderName: _currentUserName ?? '匿名',
      content: content,
      timestamp: DateTime.now(),
      isFromBot: _isBot,
    );
    
    _messages[roomId]?.add(message);
    _messageController.add(message);
    
    _logger.i('发送消息: [$roomId] ${_currentUserName}: $content');
    
    // 通过 P2P 发送到其他设备
    _p2pService?.sendChatMessage(
      roomId: roomId,
      content: content,
    );
  }
  
  /// 接收消息（从外部，如 Gateway）
  void receiveMessage(Map<String, dynamic> messageData) {
    final message = GroupChatMessage.fromJson(messageData);
    
    _messages[message.roomId]?.add(message);
    _messageController.add(message);
    
    _logger.i('接收消息: [${message.roomId}] ${message.senderName}: ${message.content}');
  }
  
  /// 获取房间消息历史
  List<GroupChatMessage> getRoomMessages(String roomId) {
    return _messages[roomId] ?? [];
  }
  
  /// 获取房间信息
  ChatRoom? getRoom(String roomId) => _rooms[roomId];
  
  /// 清理资源
  void dispose() {
    _messageController.close();
    _roomController.close();
    _p2pService?.dispose();
  }
  
  /// 处理 P2P 消息
  void _handleP2PMessage(P2PMessage p2pMessage) {
    switch (p2pMessage.type) {
      case P2PMessageType.chatMessage:
        _handleChatMessage(p2pMessage);
        break;
      case P2PMessageType.joinRoom:
        _handleJoinRoom(p2pMessage);
        break;
      case P2PMessageType.syncRequest:
        _handleSyncRequest(p2pMessage);
        break;
      default:
        _logger.d('未处理的 P2P 消息类型: ${p2pMessage.type}');
    }
  }
  
  /// 处理聊天消息
  void _handleChatMessage(P2PMessage p2pMessage) {
    final roomId = p2pMessage.payload['roomId'] as String?;
    final content = p2pMessage.payload['content'] as String?;
    
    if (roomId == null || content == null) return;
    
    // 创建消息
    final message = GroupChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${p2pMessage.fromId}',
      roomId: roomId,
      senderId: p2pMessage.fromId,
      senderName: p2pMessage.fromName,
      content: content,
      timestamp: p2pMessage.timestamp,
      isFromBot: p2pMessage.payload['isFromBot'] ?? false,
    );
    
    // 添加到消息历史
    _messages[roomId]?.add(message);
    _messageController.add(message);
    
    _logger.i('接收 P2P 消息: [$roomId] ${p2pMessage.fromName}: $content');
    
    // 如果是机器人且开启了自动回复
    if (_isBot && _botAutoReply && p2pMessage.fromId != _currentUserId) {
      _generateBotReply(roomId, content);
    }
  }
  
  /// 处理加入房间
  void _handleJoinRoom(P2PMessage p2pMessage) {
    // 远程设备加入房间的逻辑
    _logger.i('远程设备加入: ${p2pMessage.fromName}');
  }
  
  /// 处理同步请求
  void _handleSyncRequest(P2PMessage p2pMessage) {
    final roomId = p2pMessage.payload['roomId'] as String?;
    if (roomId == null) return;
    
    // 发送消息历史
    final messages = _messages[roomId] ?? [];
    final response = P2PMessage(
      type: P2PMessageType.syncResponse,
      fromId: _currentUserId!,
      fromName: _currentUserName!,
      payload: {
        'roomId': roomId,
        'messages': messages.map((m) => m.toJson()).toList(),
      },
    );
    
    _p2pService?.sendTo(p2pMessage.fromId, response);
  }
  
  /// 生成机器人回复
  Future<void> _generateBotReply(String roomId, String userMessage) async {
    if (_llmProvider == null) {
      _logger.w('LLM 服务未初始化，无法生成机器人回复');
      return;
    }
    
    try {
      // 获取最近的消息上下文
      final recentMessages = (_messages[roomId] ?? [])
          .skip((_messages[roomId]?.length ?? 0) - 10)
          .map((m) => '${m.senderName}: ${m.content}')
          .join('\n');
      
      // 调用 LLM 生成回复
      final messages = [
        ChatMessage.system(_botSystemPrompt),
        ChatMessage.user('群聊记录：\n$recentMessages\n\n请根据上下文回复最后一条消息：$userMessage'),
      ];
      
      final response = await _llmProvider!.chat(messages);
      final reply = response.content;
      
      // 发送回复
      if (reply != null && reply.isNotEmpty) {
        // 延迟一下，模拟思考
        await Future.delayed(Duration(milliseconds: 500 + reply.length * 20));
        
        sendMessage(roomId, reply);
        _logger.i('机器人自动回复: $reply');
      }
    } catch (e) {
      _logger.e('生成机器人回复失败: $e');
    }
  }
  
  /// 连接到远程设备
  Future<bool> connectToDevice({
    required String deviceId,
    required String deviceName,
    required String ipAddress,
    int port = 18790,
  }) async {
    return await _p2pService?.connectToDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      ipAddress: ipAddress,
      port: port,
    ) ?? false;
  }
  
  /// 获取已连接的设备
  List<dynamic> get connectedDevices => _p2pService?.connections ?? [];
}

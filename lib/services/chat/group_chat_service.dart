// 群聊服务
//
// 实现多个小紫霞机器人 + 用户群聊

import 'dart:async';
import 'package:logger/logger.dart';

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
  
  /// 初始化用户信息
  void initUser({
    required String userId,
    required String userName,
    bool isBot = false,
  }) {
    _currentUserId = userId;
    _currentUserName = userName;
    _isBot = isBot;
    _logger.i('群聊服务初始化: $userName (${isBot ? '机器人' : '用户'})');
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
  }
}

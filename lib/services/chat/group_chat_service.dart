// 群聊服务（协议 v1.0 - 协同改造）
//
// 实现多个小紫霞机器人 + 用户群聊
// 协议版本: v1.0 (2026-04-06)
// 基于: LittleZiXia_Android_CollabAction_v0.5.0+20260406

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'p2p_messaging.dart';
import '../llm/llm_base.dart';
import '../llm/llm_factory.dart';

/// 消息内容类型（扩展）
enum ContentType {
  text,      // 文本
  image,     // 图片
  file,      // 文件
  voice,     // 语音
  video,     // 视频
  location, // 位置
}

/// 群聊房间
class ChatRoom {
  final String id;
  final String name;
  final List<String> members;
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

/// 群聊消息（扩展）
class GroupChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final ContentType contentType;  // 新增
  final dynamic content;  // 支持多种类型
  final DateTime timestamp;
  final bool isFromBot;
  
  // 文件相关（新增）
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  
  // 语音/视频相关（新增）
  final int? duration;  // 秒
  
  // 缩略图（新增）
  final String? thumbnail;

  GroupChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.contentType,
    required this.content,
    required this.timestamp,
    this.isFromBot = false,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.duration,
    this.thumbnail,
  });

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) {
    return GroupChatMessage(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '匿名',
      contentType: ContentType.values.firstWhere(
        (e) => e.name == json['contentType'],
        orElse: () => ContentType.text,
      ),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isFromBot: json['isFromBot'] ?? false,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType'] as String?,
      duration: json['duration'] as int?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'contentType': contentType.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isFromBot': isFromBot,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (mimeType != null) 'mimeType': mimeType,
      if (duration != null) 'duration': duration,
      if (thumbnail != null) 'thumbnail': thumbnail,
    };
    return json;
  }
  
  /// 是否是多媒体消息
  bool get isMultimedia => contentType != ContentType.text;
  
  /// 获取显示文本（用于 UI）
  String get displayText {
    switch (contentType) {
      case ContentType.text:
        return content as String;
      case ContentType.image:
        return '[图片]';
      case ContentType.file:
        return '[文件] $fileName';
      case ContentType.voice:
        return '[语音] ${duration}秒';
      case ContentType.video:
        return '[视频] ${duration}秒';
      case ContentType.location:
        return '[位置] $content';
      default:
        return '[未知消息]';
    }
  }
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
  
  // 文件存储路径（新增）
  String? _fileStoragePath;
  
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
    String? fileStoragePath,  // 新增
  }) async {
    _currentUserId = userId;
    _currentUserName = userName;
    _isBot = isBot;
    _llmProvider = llmProvider;
    _fileStoragePath = fileStoragePath ?? (await _getDefaultStoragePath());
    
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
  
  /// 获取默认存储路径
  Future<String> _getDefaultStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/chat_files';
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
      members: members.toSet().toList(),
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
  
  /// 发送文本消息
  void sendTextMessage(String roomId, String text) {
    _sendMessage(
      roomId: roomId,
      contentType: ContentType.text,
      content: text,
    );
  }
  
  /// 发送图片消息（新增）
  void sendImageMessage(String roomId, String imageBase64, {String? caption}) {
    _sendMessage(
      roomId: roomId,
      contentType: ContentType.image,
      content: imageBase64,
      metadata: caption != null ? {'caption': caption} : null,
    );
  }
  
  /// 发送文件消息（新增）
  Future<void> sendFileMessage(String roomId, File file) async {
    try {
      // 读取文件
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      final fileName = file.path.split('/').last;
      final fileSize = bytes.length;
      
      _sendMessage(
        roomId: roomId,
        contentType: ContentType.file,
        content: base64,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: _getMimeType(fileName),
      );
      
      _logger.i('发送文件: $fileName ($fileSize bytes)');
    } catch (e) {
      _logger.e('发送文件失败: $e');
    }
  }
  
  /// 发送语音消息（新增）
  void sendVoiceMessage(String roomId, String voiceBase64, int durationSeconds) {
    _sendMessage(
      roomId: roomId,
      contentType: ContentType.voice,
      content: voiceBase64,
      duration: durationSeconds,
    );
  }
  
  /// 发送视频消息（新增）
  void sendVideoMessage(String roomId, String videoBase64, int durationSeconds, {String? thumbnail}) {
    _sendMessage(
      roomId: roomId,
      contentType: ContentType.video,
      content: videoBase64,
      duration: durationSeconds,
      thumbnail: thumbnail,
    );
  }
  
  /// 发送位置消息（新增）
  void sendLocationMessage(String roomId, double latitude, double longitude, {String? address}) {
    final locationData = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    });
    
    _sendMessage(
      roomId: roomId,
      contentType: ContentType.location,
      content: locationData,
    );
  }
  
  /// 内部发送消息
  void _sendMessage({
    required String roomId,
    required ContentType contentType,
    required dynamic content,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? duration,
    String? thumbnail,
    Map<String, dynamic>? metadata,
  }) {
    if (_currentUserId == null) {
      _logger.e('未初始化用户信息');
      return;
    }
    
    final message = GroupChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: _currentUserId!,
      senderName: _currentUserName ?? '匿名',
      contentType: contentType,
      content: content,
      timestamp: DateTime.now(),
      isFromBot: _isBot,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      duration: duration,
      thumbnail: thumbnail,
    );
    
    _messages[roomId]?.add(message);
    _messageController.add(message);
    
    _logger.i('发送消息: [$roomId] ${_currentUserName}: ${message.displayText}');
    
    // 通过 P2P 发送
    if (_p2pService != null) {
      _p2pService!.sendChatMessage(
        roomId: roomId,
        content: content is String ? content : jsonEncode(content),
        contentType: contentType.name,
        metadata: {
          if (fileName != null) 'fileName': fileName,
          if (fileSize != null) 'fileSize': fileSize,
          if (mimeType != null) 'mimeType': mimeType,
          if (duration != null) 'duration': duration,
          if (thumbnail != null) 'thumbnail': thumbnail,
          ...?metadata ?? {},
        },
      );
    }
    
    // 触发机器人回复
    if (!_isBot && _botAutoReply) {
      _generateBotReply(roomId, content is String ? content : message.displayText);
    }
  }
  
  /// 处理 P2P 消息
  void _handleP2PMessage(P2PMessage p2pMessage) {
    if (p2pMessage.type != P2PMessageType.chatMessage) return;
    
    final roomId = p2pMessage.payload['roomId'] as String?;
    if (roomId == null) return;
    
    final contentType = ContentType.values.firstWhere(
      (e) => e.name == p2pMessage.payload['contentType'],
      orElse: () => ContentType.text,
    );
    
    final message = GroupChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${p2pMessage.fromId}',
      roomId: roomId,
      senderId: p2pMessage.fromId,
      senderName: p2pMessage.fromName,
      contentType: contentType,
      content: p2pMessage.payload['content'],
      timestamp: p2pMessage.timestamp,
      isFromBot: false,
      fileName: p2pMessage.payload['fileName'] as String?,
      fileSize: p2pMessage.payload['fileSize'] as int?,
      mimeType: p2pMessage.payload['mimeType'] as String?,
      duration: p2pMessage.payload['duration'] as int?,
      thumbnail: p2pMessage.payload['thumbnail'] as String?,
    );
    
    _messages[roomId]?.add(message);
    _messageController.add(message);
    
    _logger.i('接收 P2P 消息: ${message.displayText}');
    
    // 触发机器人回复
    if (!_isBot && _botAutoReply) {
      _generateBotReply(roomId, message.displayText);
    }
  }
  
  /// 处理同步请求
  void _handleSyncRequest(P2PMessage p2pMessage) {
    final roomId = p2pMessage.payload['roomId'] as String?;
    if (roomId == null) return;
    
    final messages = _messages[roomId] ?? [];
    
    // 发送同步响应
    _p2pService?.sendChatMessage(
      roomId: roomId,
      content: jsonEncode(messages.map((m) => m.toJson()).toList()),
      contentType: 'sync',
    );
  }
  
  /// 处理同步响应
  void _handleSyncResponse(P2PMessage p2pMessage) {
    final roomId = p2pMessage.payload['roomId'] as String?;
    if (roomId == null) return;
    
    try {
      final messagesJson = jsonDecode(p2pMessage.payload['content']) as List;
      final messages = messagesJson.map((json) => GroupChatMessage.fromJson(json)).toList();
      
      _messages[roomId] = messages;
      _logger.i('同步消息成功: ${messages.length}条');
    } catch (e) {
      _logger.e('同步消息失败: $e');
    }
  }
  
  /// 生成机器人回复
  Future<void> _generateBotReply(String roomId, String userMessage) async {
    if (_llmProvider == null) {
      _logger.w('LLM 服务未初始化');
      return;
    }
    
    try {
      // 获取最近的消息上下文
      final recentMessages = (_messages[roomId] ?? [])
          .skip((_messages[roomId]?.length ?? 0) - 10)
          .map((m) => '${m.senderName}: ${m.content}')
          .join('\n');
      
      // 构建提示
      final prompt = '''
$_botSystemPrompt

群聊记录:
$recentMessages

最后一条消息: $userMessage

请回复最后一条消息:
''';
      
      // 调用 LLM
      final response = await _llmProvider!.chat([
        ChatMessage.system(_botSystemPrompt),
        ChatMessage.user('群聊记录:\n$recentMessages\n\n请回复最后一条消息: $userMessage'),
      ]);
      
      final reply = response.content;
      
      // 发送回复
      if (reply != null && reply.isNotEmpty) {
        await Future.delayed(Duration(milliseconds: 500 + reply.length * 20));
        sendTextMessage(roomId, reply);
        _logger.i('机器人自动回复: $reply');
      }
    } catch (e) {
      _logger.e('生成机器人回复失败: $e');
    }
  }
  
  /// 获取 MIME 类型
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
  
  /// 保存文件（新增）
  Future<String?> saveFile(String fileName, String base64Data) async {
    final storagePath = _fileStoragePath;
    if (storagePath == null) return null;
    
    try {
      final directory = Directory(storagePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('$storagePath/$fileName');
      await file.writeAsBytes(base64Decode(base64Data));
      
      _logger.i('文件已保存: $fileName');
      return file.path;
    } catch (e) {
      _logger.e('保存文件失败: $e');
      return null;
    }
  }
  
  /// 获取消息历史
  List<GroupChatMessage> getMessages(String roomId) {
    return _messages[roomId] ?? [];
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

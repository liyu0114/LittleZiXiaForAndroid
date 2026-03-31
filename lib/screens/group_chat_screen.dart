// 群聊屏幕
//
// 显示群聊房间列表和聊天界面

import 'package:flutter/material.dart';
import '../services/chat/group_chat_service.dart';
import '../services/chat/lan_discovery.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _chatService = GroupChatService();
  final LanDiscoveryService _discoveryService = LanDiscoveryService();
  
  final _messageController = TextEditingController();
  final _roomNameController = TextEditingController();
  
  ChatRoom? _currentRoom;
  List<GroupChatMessage> _messages = [];
  
  // 发现的设备列表
  List<DiscoveredDevice> _nearbyDevices = [];
  List<DiscoveredRoom> _nearbyRooms = [];
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _initServices();
  }
  
  void _initServices() async {
    final deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    
    // 初始化群聊服务
    _chatService.initUser(
      userId: deviceId,
      userName: '小紫霞用户',
      isBot: false,
    );
    
    // 初始化发现服务
    _discoveryService.init(
      deviceId: deviceId,
      deviceName: '小紫霞用户',
      isBot: false,
    );
    
    // 监听消息
    _chatService.messageStream.listen((message) {
      if (message.roomId == _currentRoom?.id) {
        setState(() {
          _messages = _chatService.getRoomMessages(message.roomId);
        });
      }
    });
    
    // 监听发现的设备
    _discoveryService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _nearbyDevices = devices;
        });
      }
    });
    
    // 监听发现的房间
    _discoveryService.roomsStream.listen((rooms) {
      if (mounted) {
        setState(() {
          _nearbyRooms = rooms;
        });
      }
    });
    
    // 开始扫描
    _startScanning();
  }
  
  void _startScanning() async {
    setState(() => _isScanning = true);
    await _discoveryService.start();
    
    // 3秒后停止扫描状态
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _roomNameController.dispose();
    _chatService.dispose();
    _discoveryService.dispose();
    super.dispose();
  }
  
  void _createRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建群聊房间'),
        content: TextField(
          controller: _roomNameController,
          decoration: const InputDecoration(
            labelText: '房间名称',
            hintText: '输入房间名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (_roomNameController.text.isNotEmpty) {
                final room = _chatService.createRoom(_roomNameController.text);
                
                // 广播房间信息
                _discoveryService.setCurrentRoom(room.id, room.name);
                
                setState(() {
                  _currentRoom = room;
                  _messages = [];
                });
                _roomNameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
  
  void _joinNearbyRoom(DiscoveredRoom room) {
    // 创建本地房间副本
    final localRoom = _chatService.createRoom(room.name);
    
    // 设置为当前房间
    setState(() {
      _currentRoom = localRoom;
      _messages = [];
    });
    
    // 广播自己加入了
    _discoveryService.setCurrentRoom(room.id, room.name);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已加入 ${room.name}')),
    );
  }
  
  void _sendMessage() {
    if (_messageController.text.isEmpty || _currentRoom == null) return;
    _chatService.sendMessage(_currentRoom!.id, _messageController.text);
    _messageController.clear();
  }
  
  void _showRoomInfo() {
    if (_currentRoom == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('房间信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('房间名称: ${_currentRoom!.name}'),
            const SizedBox(height: 8),
            const Text('附近设备会自动发现此房间', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoom?.name ?? '群聊'),
        actions: [
          if (_currentRoom != null) ...[
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showRoomInfo,
              tooltip: '房间信息',
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                _discoveryService.setCurrentRoom(null, null);
                setState(() {
                  _currentRoom = null;
                  _messages = [];
                });
              },
              tooltip: '退出房间',
            ),
          ] else ...[
            IconButton(
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isScanning ? null : _startScanning,
              tooltip: '扫描附近',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createRoom,
              tooltip: '创建房间',
            ),
          ],
        ],
      ),
      body: _currentRoom == null ? _buildRoomList() : _buildChatView(),
    );
  }
  
  Widget _buildRoomList() {
    return RefreshIndicator(
      onRefresh: () async {
        _startScanning();
        await Future.delayed(const Duration(seconds: 2));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 附近房间
          if (_nearbyRooms.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.wifi, size: 20),
                const SizedBox(width: 8),
                Text('附近的房间', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...(_nearbyRooms.map((room) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.group),
                ),
                title: Text(room.name),
                subtitle: Text('创建者: ${room.hostName}'),
                trailing: FilledButton(
                  onPressed: () => _joinNearbyRoom(room),
                  child: const Text('加入'),
                ),
              ),
            ))),
            const SizedBox(height: 16),
          ],
          
          // 附近设备
          if (_nearbyDevices.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.devices, size: 20),
                const SizedBox(width: 8),
                Text('附近的设备 (${_nearbyDevices.length})', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...(_nearbyDevices.map((device) => ListTile(
              leading: CircleAvatar(
                child: Icon(device.isBot ? Icons.smart_toy : Icons.person),
              ),
              title: Text(device.name),
              subtitle: Text(device.isBot ? '机器人' : '用户'),
            ))),
            const SizedBox(height: 16),
          ],
          
          // 空状态
          if (_nearbyRooms.isEmpty && _nearbyDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      _isScanning ? Icons.wifi_find : Icons.people_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning ? '正在扫描附近设备...' : '附近暂无其他设备',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    if (!_isScanning) ...[
                      FilledButton.icon(
                        onPressed: _createRoom,
                        icon: const Icon(Icons.add),
                        label: const Text('创建房间'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '创建房间后，附近设备会自动发现',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildChatView() {
    return Column(
      children: [
        // 房间信息栏
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.wifi, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentRoom!.name,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  _discoveryService.setCurrentRoom(null, null);
                  setState(() {
                    _currentRoom = null;
                    _messages = [];
                  });
                },
                child: const Text('退出'),
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
                      Text('等待其他人加入...', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg.senderId == _chatService.currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe 
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${msg.senderName}${msg.isFromBot ? ' 🤖' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
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
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

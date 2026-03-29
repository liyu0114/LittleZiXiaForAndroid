// P2P 节点管理
//
// 管理分布式网络中的节点

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 节点角色
enum NodeRole {
  server,  // 服务器节点
  client,  // 客户端节点
  standalone,  // 独立模式
}

/// 节点状态
enum NodeStatus {
  offline,      // 离线
  starting,     // 启动中
  online,       // 在线
  connecting,   // 连接中
  connected,    // 已连接
  error,        // 错误
}

/// 节点信息
class NodeInfo {
  final String id;
  final String name;
  final String? address;  // IP:Port
  final NodeRole role;
  final NodeStatus status;
  final DateTime? connectedAt;
  final String? errorMessage;

  const NodeInfo({
    required this.id,
    required this.name,
    this.address,
    this.role = NodeRole.standalone,
    this.status = NodeStatus.offline,
    this.connectedAt,
    this.errorMessage,
  });

  NodeInfo copyWith({
    String? id,
    String? name,
    String? address,
    NodeRole? role,
    NodeStatus? status,
    DateTime? connectedAt,
    String? errorMessage,
  }) {
    return NodeInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      role: role ?? this.role,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get displayName {
    if (name.isNotEmpty) return name;
    return id.substring(0, 8);
  }

  String get statusText {
    switch (status) {
      case NodeStatus.offline:
        return '离线';
      case NodeStatus.starting:
        return '启动中...';
      case NodeStatus.online:
        return '在线';
      case NodeStatus.connecting:
        return '连接中...';
      case NodeStatus.connected:
        return '已连接';
      case NodeStatus.error:
        return '错误';
    }
  }

  String get statusIcon {
    switch (status) {
      case NodeStatus.offline:
        return '○';
      case NodeStatus.starting:
      case NodeStatus.connecting:
        return '◐';
      case NodeStatus.online:
      case NodeStatus.connected:
        return '●';
      case NodeStatus.error:
        return '✗';
    }
  }
}

/// P2P 消息
class P2PMessage {
  final String type;      // chat/command/status/system
  final String from;      // 发送者 ID
  final String? to;       // 接收者 ID（null = 广播）
  final dynamic payload;  // 消息内容
  final DateTime timestamp;

  const P2PMessage({
    required this.type,
    required this.from,
    this.to,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory P2PMessage.fromJson(Map<String, dynamic> json) {
    return P2PMessage(
      type: json['type'] as String,
      from: json['from'] as String,
      to: json['to'] as String?,
      payload: json['payload'],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'from': from,
      'to': to,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String encode() => jsonEncode(toJson());

  static P2PMessage decode(String str) => P2PMessage.fromJson(jsonDecode(str));
}

/// P2P 节点管理器
class P2PNodeManager extends ChangeNotifier {
  NodeInfo _localNode = NodeInfo(
    id: _generateNodeId(),
    name: '小紫霞',
    role: NodeRole.standalone,
  );

  final Map<String, NodeInfo> _remoteNodes = {};
  final Map<String, WebSocket> _connections = {};
  final StreamController<P2PMessage> _messageController = StreamController.broadcast();

  ServerSocket? _serverSocket;
  WebSocket? _clientSocket;
  int _serverPort = 18790;

  // Getters
  NodeInfo get localNode => _localNode;
  List<NodeInfo> get remoteNodes => _remoteNodes.values.toList();
  Stream<P2PMessage> get messageStream => _messageController.stream;
  bool get isServer => _localNode.role == NodeRole.server;
  bool get isConnected => _connections.isNotEmpty;

  /// 生成节点 ID
  static String _generateNodeId() {
    return 'zixia_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 启动服务器
  Future<bool> startServer({int? port}) async {
    if (_serverSocket != null) {
      debugPrint('[P2PNode] 服务器已在运行');
      return false;
    }

    _serverPort = port ?? _serverPort;

    _updateLocalNode(
      status: NodeStatus.starting,
      role: NodeRole.server,
    );

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _serverPort,
      );

      _serverSocket!.listen(_handleNewConnection);

      _updateLocalNode(
        status: NodeStatus.online,
        address: '${_getLocalIP()}:$_serverPort',
      );

      debugPrint('[P2PNode] 服务器已启动: ${_localNode.address}');
      return true;
    } catch (e) {
      debugPrint('[P2PNode] 启动服务器失败: $e');
      _updateLocalNode(
        status: NodeStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    await _serverSocket?.close();
    _serverSocket = null;

    // 关闭所有客户端连接
    for (final socket in _connections.values) {
      await socket.close();
    }
    _connections.clear();
    _remoteNodes.clear();

    _updateLocalNode(
      status: NodeStatus.offline,
      role: NodeRole.standalone,
      address: null,
    );

    debugPrint('[P2PNode] 服务器已停止');
    notifyListeners();
  }

  /// 连接到服务器
  Future<bool> connectToServer(String address) async {
    if (_clientSocket != null) {
      debugPrint('[P2PNode] 已有连接');
      return false;
    }

    _updateLocalNode(
      status: NodeStatus.connecting,
      role: NodeRole.client,
    );

    try {
      final parts = address.split(':');
      final host = parts[0];
      final port = int.tryParse(parts[1]) ?? 18790;

      _clientSocket = await WebSocket.connect('ws://$host:$port');

      _clientSocket!.listen(
        (data) => _handleMessage(data, 'server'),
        onError: (error) => _handleError(error, 'server'),
        onDone: () => _handleDisconnect('server'),
      );

      // 发送握手消息
      _sendHandshake(_clientSocket!);

      _updateLocalNode(
        status: NodeStatus.connected,
        address: address,
        connectedAt: DateTime.now(),
      );

      debugPrint('[P2PNode] 已连接到服务器: $address');
      return true;
    } catch (e) {
      debugPrint('[P2PNode] 连接失败: $e');
      _updateLocalNode(
        status: NodeStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _clientSocket?.close();
    _clientSocket = null;
    _connections.clear();
    _remoteNodes.clear();

    _updateLocalNode(
      status: NodeStatus.offline,
      role: NodeRole.standalone,
      address: null,
    );

    debugPrint('[P2PNode] 已断开连接');
    notifyListeners();
  }

  /// 发送消息
  void sendMessage(P2PMessage message) {
    final encoded = message.encode();

    if (isServer) {
      // 服务器广播给所有客户端
      for (final socket in _connections.values) {
        socket.add(encoded);
      }
    } else if (_clientSocket != null) {
      // 客户端发送给服务器
      _clientSocket!.add(encoded);
    }
  }

  /// 广播聊天消息
  void broadcastChat(String content, {String? to}) {
    sendMessage(P2PMessage(
      type: 'chat',
      from: _localNode.id,
      to: to,
      payload: {
        'content': content,
        'sender': _localNode.name,
      },
    ));
  }

  /// 处理新连接（服务器）
  void _handleNewConnection(Socket socket) {
    debugPrint('[P2PNode] 新连接: ${socket.remoteAddress.address}');

    // 升级为 WebSocket
    WebSocketTransformer.upgrade(socket).then((webSocket) {
      final nodeId = 'node_${socket.remoteAddress.address}_${socket.remotePort}';

      _connections[nodeId] = webSocket;
      _remoteNodes[nodeId] = NodeInfo(
        id: nodeId,
        name: 'Unknown',
        address: '${socket.remoteAddress.address}:${socket.remotePort}',
        role: NodeRole.client,
        status: NodeStatus.connected,
        connectedAt: DateTime.now(),
      );

      webSocket.listen(
        (data) => _handleMessage(data, nodeId),
        onError: (error) => _handleError(error, nodeId),
        onDone: () => _handleDisconnect(nodeId),
      );

      notifyListeners();
    });
  }

  /// 处理消息
  void _handleMessage(dynamic data, String fromNodeId) {
    try {
      final message = P2PMessage.decode(data as String);
      debugPrint('[P2PNode] 收到消息: ${message.type}');

      // 如果是握手消息，更新节点信息
      if (message.type == 'handshake') {
        final payload = message.payload as Map<String, dynamic>;
        final name = payload['name'] as String? ?? 'Unknown';
        
        if (_remoteNodes.containsKey(fromNodeId)) {
          _remoteNodes[fromNodeId] = _remoteNodes[fromNodeId]!.copyWith(
            name: name,
          );
          notifyListeners();
        }
        return;
      }

      // 转发给应用层
      _messageController.add(message);

      // 如果是服务器，广播给其他客户端
      if (isServer && message.to == null) {
        for (final entry in _connections.entries) {
          if (entry.key != fromNodeId) {
            entry.value.add(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[P2Node] 消息处理失败: $e');
    }
  }

  /// 处理错误
  void _handleError(dynamic error, String nodeId) {
    debugPrint('[P2PNode] 连接错误 [$nodeId]: $error');
    
    if (_remoteNodes.containsKey(nodeId)) {
      _remoteNodes[nodeId] = _remoteNodes[nodeId]!.copyWith(
        status: NodeStatus.error,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  /// 处理断开连接
  void _handleDisconnect(String nodeId) {
    debugPrint('[P2PNode] 断开连接: $nodeId');

    _connections.remove(nodeId);
    _remoteNodes.remove(nodeId);

    if (nodeId == 'server') {
      _updateLocalNode(status: NodeStatus.offline);
    }

    notifyListeners();
  }

  /// 发送握手消息
  void _sendHandshake(WebSocket socket) {
    final message = P2PMessage(
      type: 'handshake',
      from: _localNode.id,
      payload: {
        'name': _localNode.name,
        'id': _localNode.id,
      },
    );
    socket.add(message.encode());
  }

  /// 更新本地节点状态
  void _updateLocalNode({
    NodeStatus? status,
    NodeRole? role,
    String? address,
    DateTime? connectedAt,
    String? errorMessage,
  }) {
    _localNode = _localNode.copyWith(
      status: status,
      role: role,
      address: address,
      connectedAt: connectedAt,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  /// 获取本地 IP
  String _getLocalIP() {
    try {
      for (final interface in NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('[P2PNode] 获取本地 IP 失败: $e');
    }
    return '127.0.0.1';
  }

  @override
  void dispose() {
    stopServer();
    disconnect();
    _messageController.close();
    super.dispose();
  }
}

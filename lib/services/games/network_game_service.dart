// 网络游戏服务 - 主机权威架构
//
// 设计原则：
// - 主机是权威：所有游戏逻辑在主机执行
// - 客户端是"显示器"：只显示主机发来的状态
// - 高频同步：主机每秒广播游戏状态（包括倒计时）
// - 操作转发：客户端操作发送给主机，主机处理后再广播

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:logger/logger.dart';

/// 网络游戏消息类型
enum NetworkGameMessageType {
  joinGame,      // 加入游戏
  leaveGame,     // 离开游戏
  gameState,     // 游戏状态同步（高频，每秒）
  rush,          // 抢答
  submitAnswer,  // 提交答案
  startGame,     // 开始游戏
  addBot,        // 添加机器人
  playerList,    // 玩家列表更新
}

/// 网络游戏消息
class NetworkGameMessage {
  final NetworkGameMessageType type;
  final String fromId;
  final String fromName;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  NetworkGameMessage({
    required this.type,
    required this.fromId,
    required this.fromName,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NetworkGameMessage.fromJson(Map<String, dynamic> json) {
    return NetworkGameMessage(
      type: NetworkGameMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NetworkGameMessageType.gameState,
      ),
      fromId: json['fromId'] ?? '',
      fromName: json['fromName'] ?? 'Unknown',
      payload: json['payload'] ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'fromId': fromId,
    'fromName': fromName,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static NetworkGameMessage decode(String data) {
    return NetworkGameMessage.fromJson(jsonDecode(data));
  }
}

/// 远程玩家信息
class RemotePlayer {
  final String id;
  final String name;
  Socket socket;
  
  RemotePlayer({
    required this.id,
    required this.name,
    required this.socket,
  });
}

/// 网络游戏服务
class NetworkGameService {
  final Logger _logger = Logger();

  // 本机信息
  String? _localPlayerId;
  String? _localPlayerName;
  int _localPort = 18791;

  // 是否是主机
  bool _isHost = false;
  bool get isHost => _isHost;

  // 主机服务器
  ServerSocket? _server;
  
  // 连接的玩家（主机用）
  final Map<String, RemotePlayer> _players = {};
  
  // 连接到主机的 socket（客户端用）
  Socket? _hostSocket;

  // 状态广播定时器（主机用）
  Timer? _broadcastTimer;

  // 流控制器
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  /// 游戏状态流（客户端监听）
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  
  /// 消息流（提示消息）
  Stream<String> get messageStream => _messageController.stream;

  /// 当前游戏状态（客户端存储）
  Map<String, dynamic> _gameState = {};
  Map<String, dynamic> get gameState => _gameState;

  NetworkGameService();

  /// 作为主机初始化
  Future<void> initAsHost({
    required String playerId,
    required String playerName,
    required int port,
  }) async {
    _localPlayerId = playerId;
    _localPlayerName = playerName;
    _localPort = port;
    _isHost = true;

    await _startServer();
    _logger.i('主机服务已启动 (端口: $port)');
  }

  /// 作为客户端连接
  Future<bool> connectToHost({
    required String playerId,
    required String playerName,
    required String ipAddress,
    int port = 18791,
  }) async {
    _localPlayerId = playerId;
    _localPlayerName = playerName;
    _isHost = false;

    try {
      _logger.i('连接到主机: $ipAddress:$port');

      _hostSocket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));

      // 发送加入消息
      _sendToSocket(_hostSocket!, NetworkGameMessage(
        type: NetworkGameMessageType.joinGame,
        fromId: _localPlayerId!,
        fromName: _localPlayerName!,
        payload: {},
      ));

      // 监听主机消息
      String buffer = '';
      _hostSocket!.listen(
        (data) {
          buffer += utf8.decode(data);
          while (buffer.contains('\n')) {
            final index = buffer.indexOf('\n');
            final messageStr = buffer.substring(0, index);
            buffer = buffer.substring(index + 1);

            try {
              final message = NetworkGameMessage.decode(messageStr);
              _handleHostMessage(message);
            } catch (e) {
              _logger.e('解析消息失败: $e');
            }
          }
        },
        onError: (error) {
          _logger.e('连接错误: $error');
          _messageController.add('与主机断开连接');
        },
        onDone: () {
          _logger.i('与主机断开');
          _messageController.add('与主机断开连接');
        },
      );

      _logger.i('已连接到主机');
      return true;
    } catch (e) {
      _logger.e('连接失败: $e');
      return false;
    }
  }

  /// 启动 TCP 服务器（主机）
  Future<void> _startServer() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _localPort,
      );

      _server!.listen(
        _handleIncomingConnection,
        onError: (error) {
          _logger.e('服务器错误: $error');
        },
      );

      _logger.i('服务器已启动: ${_server!.address.address}:$_localPort');
    } catch (e) {
      _logger.e('启动服务器失败: $e');
    }
  }

  /// 处理入站连接（主机）
  void _handleIncomingConnection(Socket socket) {
    _logger.i('新连接: ${socket.remoteAddress.address}:${socket.remotePort}');

    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final messageStr = buffer.substring(0, index);
          buffer = buffer.substring(index + 1);

          try {
            final message = NetworkGameMessage.decode(messageStr);
            _handleClientMessage(message, socket);
          } catch (e) {
            _logger.e('解析消息失败: $e');
          }
        }
      },
      onError: (error) {
        _logger.e('连接错误: $error');
        socket.destroy();
      },
      onDone: () {
        _logger.i('连接断开');
        _removePlayer(socket);
      },
    );
  }

  /// 处理客户端消息（主机）
  void _handleClientMessage(NetworkGameMessage message, Socket socket) {
    _logger.d('收到客户端消息: ${message.type} from ${message.fromName}');

    switch (message.type) {
      case NetworkGameMessageType.joinGame:
        _addPlayer(message, socket);
        break;

      case NetworkGameMessageType.rush:
        // 通知上层处理抢答（通过状态流）
        _stateController.add({
          'action': 'rush',
          'playerId': message.fromId,
          'playerName': message.fromName,
        });
        break;

      case NetworkGameMessageType.submitAnswer:
        // 通知上层处理答案
        _stateController.add({
          'action': 'submitAnswer',
          'playerId': message.fromId,
          'playerName': message.fromName,
          'answer': message.payload['answer'],
        });
        break;

      case NetworkGameMessageType.addBot:
        _stateController.add({'action': 'addBot'});
        break;

      case NetworkGameMessageType.startGame:
        _stateController.add({'action': 'startGame'});
        break;

      default:
        break;
    }
  }

  /// 添加玩家（主机）
  void _addPlayer(NetworkGameMessage message, Socket socket) {
    final player = RemotePlayer(
      id: message.fromId,
      name: message.fromName,
      socket: socket,
    );

    _players[player.id] = player;
    _logger.i('玩家加入: ${player.name}');

    // 通知上层有新玩家加入
    _stateController.add({
      'action': 'playerJoined',
      'playerId': player.id,
      'playerName': player.name,
    });
  }

  /// 移除玩家（主机）
  void _removePlayer(Socket socket) {
    final playerId = _players.entries
        .where((e) => e.value.socket == socket)
        .map((e) => e.key)
        .firstOrNull;

    if (playerId != null) {
      final player = _players[playerId];
      _players.remove(playerId);
      _logger.i('玩家离开: ${player?.name}');

      // 通知上层
      _stateController.add({
        'action': 'playerLeft',
        'playerId': playerId,
      });
    }
  }

  /// 处理主机消息（客户端）
  void _handleHostMessage(NetworkGameMessage message) {
    if (message.type == NetworkGameMessageType.gameState) {
      // 更新本地游戏状态
      _gameState = message.payload;
      _stateController.add(_gameState);
    } else if (message.type == NetworkGameMessageType.playerList) {
      // 玩家列表更新
      _gameState['players'] = message.payload['players'];
      _stateController.add(_gameState);
    }
  }

  /// 广播游戏状态（主机调用）
  void broadcastGameState(Map<String, dynamic> state) {
    if (!_isHost) return;

    final message = NetworkGameMessage(
      type: NetworkGameMessageType.gameState,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: state,
    );

    for (final player in _players.values) {
      _sendToSocket(player.socket, message);
    }
  }

  /// 发送玩家列表（主机调用）
  void broadcastPlayerList(List<Map<String, dynamic>> players) {
    if (!_isHost) return;

    final message = NetworkGameMessage(
      type: NetworkGameMessageType.playerList,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {'players': players},
    );

    for (final player in _players.values) {
      _sendToSocket(player.socket, message);
    }
  }

  /// 发送抢答（客户端调用）
  void sendRush() {
    if (_isHost || _hostSocket == null) return;

    _sendToSocket(_hostSocket!, NetworkGameMessage(
      type: NetworkGameMessageType.rush,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {},
    ));
  }

  /// 发送答案（客户端调用）
  void sendAnswer(String answer) {
    if (_isHost || _hostSocket == null) return;

    _sendToSocket(_hostSocket!, NetworkGameMessage(
      type: NetworkGameMessageType.submitAnswer,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {'answer': answer},
    ));
  }

  /// 请求添加机器人（客户端调用）
  void requestAddBot() {
    if (_isHost || _hostSocket == null) return;

    _sendToSocket(_hostSocket!, NetworkGameMessage(
      type: NetworkGameMessageType.addBot,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {},
    ));
  }

  /// 请求开始游戏（客户端调用）
  void requestStartGame() {
    if (_isHost || _hostSocket == null) return;

    _sendToSocket(_hostSocket!, NetworkGameMessage(
      type: NetworkGameMessageType.startGame,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {},
    ));
  }

  /// 发送消息到 socket
  void _sendToSocket(Socket socket, NetworkGameMessage message) {
    try {
      socket.writeln(message.encode());
    } catch (e) {
      _logger.e('发送失败: $e');
    }
  }

  /// 获取连接的玩家数量（主机）
  int get playerCount => _players.length;

  /// 清理资源
  Future<void> dispose() async {
    _broadcastTimer?.cancel();

    if (_isHost) {
      for (final player in _players.values) {
        player.socket.destroy();
      }
      _players.clear();
      await _server?.close();
    } else {
      _hostSocket?.destroy();
    }

    await _stateController.close();
    await _messageController.close();

    _logger.i('网络游戏服务已关闭');
  }
}

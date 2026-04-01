// 网络游戏服务
//
// 为24点游戏添加联网对战功能

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'twenty_four_game.dart';

/// 网络游戏消息类型
enum NetworkGameMessageType {
  joinGame,      // 加入游戏
  leaveGame,     // 离开游戏
  gameState,     // 游戏状态同步
  rush,          // 抢答
  submitAnswer,  // 提交答案
  startGame,     // 开始游戏
  restartGame,   // 重新开始
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

/// 网络游戏服务
class NetworkGameService {
  final Logger _logger = Logger();
  final TwentyFourGameService _gameService;

  // 本机信息
  String? _localPlayerId;
  String? _localPlayerName;
  int _localPort = 18791;

  // 服务器
  ServerSocket? _server;

  // 连接的玩家
  final Map<String, Socket> _connections = {};

  // 流控制器
  final _messageController = StreamController<NetworkGameMessage>.broadcast();

  /// 消息流
  Stream<NetworkGameMessage> get messageStream => _messageController.stream;

  /// 游戏服务
  TwentyFourGameService get gameService => _gameService;

  NetworkGameService(this._gameService);

  /// 初始化服务
  Future<void> init({
    required String playerId,
    required String playerName,
    int port = 18791,
  }) async {
    _localPlayerId = playerId;
    _localPlayerName = playerName;
    _localPort = port;

    await _startServer();

    // 监听游戏状态变化并广播
    _gameService.stateStream.listen((state) {
      _broadcastGameState(state);
    });

    _logger.i('网络游戏服务已启动 (端口: $port)');
  }

  /// 启动 TCP 服务器
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

      _logger.i('游戏服务器已启动: ${_server!.address.address}:$_localPort');
    } catch (e) {
      _logger.e('启动服务器失败: $e');
    }
  }

  /// 处理入站连接
  void _handleIncomingConnection(Socket socket) {
    _logger.i('新玩家连接: ${socket.remoteAddress.address}:${socket.remotePort}');

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
            _handleMessage(message, socket);
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
        _logger.i('玩家断开: ${socket.remoteAddress.address}');
        _handleDisconnection(socket);
      },
    );
  }

  /// 处理接收到的消息
  void _handleMessage(NetworkGameMessage message, Socket socket) {
    _logger.d('收到消息: ${message.type} from ${message.fromName}');

    switch (message.type) {
      case NetworkGameMessageType.joinGame:
        _handleJoinGame(message, socket);
        break;

      case NetworkGameMessageType.rush:
        _handleRemoteRush(message);
        break;

      case NetworkGameMessageType.submitAnswer:
        _handleRemoteAnswer(message);
        break;

      case NetworkGameMessageType.startGame:
        _gameService.startGame();
        break;

      case NetworkGameMessageType.restartGame:
        _gameService.restart();
        break;

      case NetworkGameMessageType.gameState:
        // 游戏状态同步由主机发送，客户端接收
        _messageController.add(message);
        break;

      default:
        break;
    }
  }

  /// 处理玩家加入
  void _handleJoinGame(NetworkGameMessage message, Socket socket) {
    _connections[message.fromId] = socket;

    // 添加玩家到游戏
    _gameService.joinRoom(GamePlayer(
      id: message.fromId,
      name: message.fromName,
      isBot: false,
    ));

    _logger.i('玩家加入: ${message.fromName}');

    // 广播当前游戏状态给新玩家
    _sendGameState(message.fromId);
  }

  /// 处理远程抢答
  void _handleRemoteRush(NetworkGameMessage message) {
    // TODO: 实现远程玩家抢答逻辑
    _logger.i('远程玩家抢答: ${message.fromName}');
  }

  /// 处理远程答案
  void _handleRemoteAnswer(NetworkGameMessage message) {
    final answer = message.payload['answer'] as String?;
    if (answer != null) {
      _gameService.submitAnswer(answer);
    }
  }

  /// 处理断开连接
  void _handleDisconnection(Socket socket) {
    final playerId = _connections.entries
        .where((e) => e.value == socket)
        .map((e) => e.key)
        .firstOrNull;

    if (playerId != null) {
      _connections.remove(playerId);
      _logger.i('玩家离开: $playerId');
    }
  }

  /// 连接到主机
  Future<bool> connectToHost({
    required String hostId,
    required String hostName,
    required String ipAddress,
    int port = 18791,
  }) async {
    try {
      _logger.i('连接到主机: $hostName ($ipAddress:$port)');

      final socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));

      _connections[hostId] = socket;

      // 发送加入消息
      final joinMessage = NetworkGameMessage(
        type: NetworkGameMessageType.joinGame,
        fromId: _localPlayerId!,
        fromName: _localPlayerName!,
        payload: {
          'port': _localPort,
        },
      );

      socket.writeln(joinMessage.encode());

      // 监听消息
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
              _messageController.add(message);

              // 处理游戏状态同步
              if (message.type == NetworkGameMessageType.gameState) {
                _syncGameState(message.payload);
              }
            } catch (e) {
              _logger.e('解析消息失败: $e');
            }
          }
        },
        onError: (error) {
          _logger.e('连接错误: $error');
          _connections.remove(hostId);
        },
        onDone: () {
          _logger.i('与主机断开');
          _connections.remove(hostId);
        },
      );

      _logger.i('已连接到主机: $hostName');
      return true;
    } catch (e) {
      _logger.e('连接失败: $e');
      return false;
    }
  }

  /// 广播游戏状态
  void _broadcastGameState(Map<String, dynamic> state) {
    final message = NetworkGameMessage(
      type: NetworkGameMessageType.gameState,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: state,
    );

    final encoded = message.encode();

    for (final socket in _connections.values) {
      try {
        socket.writeln(encoded);
      } catch (e) {
        _logger.e('广播失败: $e');
      }
    }
  }

  /// 发送游戏状态给指定玩家
  void _sendGameState(String playerId) {
    final socket = _connections[playerId];
    if (socket == null) return;

    // 获取当前游戏状态
    final state = {
      'room': _gameService.currentRoom?.toJson(),
      'numbers': _gameService.currentNumbers,
      'timeLeft': _gameService.timeLeft,
    };

    final message = NetworkGameMessage(
      type: NetworkGameMessageType.gameState,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: state,
    );

    socket.writeln(message.encode());
  }

  /// 同步游戏状态（客户端）
  void _syncGameState(Map<String, dynamic> state) {
    // 客户端接收主机发来的游戏状态并更新本地游戏
    _logger.d('同步游戏状态: $state');

    // 触发消息流，让 UI 更新
    _messageController.add(NetworkGameMessage(
      type: NetworkGameMessageType.gameState,
      fromId: 'host',
      fromName: '主机',
      payload: state,
    ));
  }

  /// 发送抢答
  void sendRush() {
    final message = NetworkGameMessage(
      type: NetworkGameMessageType.rush,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {},
    );

    _broadcast(message);
  }

  /// 发送答案
  void sendAnswer(String answer) {
    final message = NetworkGameMessage(
      type: NetworkGameMessageType.submitAnswer,
      fromId: _localPlayerId!,
      fromName: _localPlayerName!,
      payload: {'answer': answer},
    );

    _broadcast(message);
  }

  /// 广播消息
  void _broadcast(NetworkGameMessage message) {
    final encoded = message.encode();

    for (final socket in _connections.values) {
      try {
        socket.writeln(encoded);
      } catch (e) {
        _logger.e('广播失败: $e');
      }
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    for (final socket in _connections.values) {
      socket.destroy();
    }
    _connections.clear();

    await _server?.close();
    await _messageController.close();

    _logger.i('网络游戏服务已关闭');
  }
}

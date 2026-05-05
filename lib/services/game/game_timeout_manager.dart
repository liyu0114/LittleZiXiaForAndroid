// 游戏断线处理服务
//
// 24点/扑克游戏超时托管

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 游戏类型
enum GameType {
  twentyFour,  // 24点
  poker,      // 扑克
}

/// 游戏状态
enum GameState {
  waiting,   // 等待中
  playing,   // 进行中
 _timeout,  // 超时托管
  finished, // 结束
}

/// 玩家
class GamePlayer {
  final String id;
  final String name;
  int score;
  bool isOnline;
  
  GamePlayer({
    required this.id,
    required this.name,
    this.score = 0,
    this.isOnline = true,
  });
}

/// 游戏房间
class GameRoom {
  final String id;
  final GameType type;
  final List<GamePlayer> players;
  GameState state;
  DateTime? startedAt;
  DateTime? lastActionAt;
  GamePlayer? aiHost;
  
  GameRoom({
    required this.id,
    required this.type,
    required this.players,
    this.state = GameState.waiting,
    this.startedAt,
    this.lastActionAt,
    this.aiHost,
  });
}

/// 游戏超时管理器
class GameTimeoutManager extends ChangeNotifier {
  static const int DEFAULT_TIMEOUT_SECONDS = 30;
  final Map<String, GameRoom> _rooms = {};
  Timer? _timeoutTimer;
  
  /// 创建房间
  Future<GameRoom> createRoom(GameType type, List<String> playerNames) async {
    final players = playerNames.asMap().entries.map((e) => GamePlayer(
      id: 'player_${e.key}',
      name: e.value,
    )).toList();
    
    final room = GameRoom(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      players: players,
    );
    
    _rooms[room.id] = room;
    notifyListeners();
    return room;
  }
  
  /// 玩家离线
  void playerOffline(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) return;
    
    final player = room.players.firstWhere((p) => p.id == playerId);
    player.isOnline = false;
    
    // 启动AI托管
    _startAIHost(room);
    notifyListeners();
  }
  
  /// 玩家恢复
  void playerOnline(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) return;
    
    final player = room.players.firstWhere((p) => p.id == playerId);
    player.isOnline = true;
    
    // 停止AI托管
    _stopAIHost(room);
    notifyListeners();
  }
  
  /// 开始游戏
  void startGame(String roomId) {
    final room = _rooms[roomId];
    if (room == null) return;
    
    room.state = GameState.playing;
    room.startedAt = DateTime.now();
    room.lastActionAt = DateTime.now();
    
    _startTimeoutCheck(room);
    notifyListeners();
  }
  
  /// 玩家操作
  void playerAction(String roomId, String playerId) {
    final room = _rooms[roomId];
    if (room == null) return;
    
    room.lastActionAt = DateTime.now();
    
    // 重置超时
    if (room.state == GameState.timeout) {
      room.state = GameState.playing;
      _stopAIHost(room);
    }
    
    notifyListeners();
  }
  
  void _startTimeoutCheck(GameRoom room) {
    // 检查超时
    Timer.periodic(Duration(seconds: 1), (_) {
      if (room.state != GameState.playing) return;
      
      final diff = DateTime.now().difference(room.lastActionAt!).inSeconds;
      if (diff >= DEFAULT_TIMEOUT_SECONDS) {
        _onTimeout(room);
      }
    });
  }
  
  void _onTimeout(GameRoom room) {
    room.state = GameState.timeout;
    
    // 创建AI托管
    _startAIHost(room);
    
    debugPrint('[GameTimeout] 玩家超时，AI托管');
    notifyListeners();
  }
  
  void _startAIHost(GameRoom room) {
    // 离线玩家由AI代玩
    for (final player in room.players) {
      if (!player.isOnline) {
        room.aiHost = player;
      }
    }
  }
  
  void _stopAIHost(GameRoom room) {
    room.aiHost = null;
  }
  
  /// 解散房间
  void dismissRoom(String roomId) {
    _rooms.remove(roomId);
    notifyListeners();
  }
}
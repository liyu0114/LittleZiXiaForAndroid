// 游戏托管服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 游戏类型
enum GameType {
  twentyFour,
  poker,
}

/// 游戏状态
enum GameState {
  waiting,
  playing,
  timeout,
  finished,
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
  
  bool get isTimedOut {
    if (lastActionAt == null) return false;
    return DateTime.now().difference(lastActionAt!).inSeconds > 30;
  }
}

/// 游戏超时管理器
class GameTimeoutManager {
  static const int DEFAULT_TIMEOUT = 30;
  final Map<String, GameRoom> _rooms = {};
  final int timeoutSeconds;
  
  GameTimeoutManager({this.timeoutSeconds = DEFAULT_TIMEOUT});
  
  GameRoom? getRoom(String id) => _rooms[id];
  
  void createRoom(String id, GameType type, List<GamePlayer> players) {
    _rooms[id] = GameRoom(
      id: id,
      type: type,
      players: players,
      state: GameState.waiting,
    );
  }
  
  void startGame(String id) {
    final room = _rooms[id];
    if (room != null) {
      room.state = GameState.playing;
      room.startedAt = DateTime.now();
      room.lastActionAt = DateTime.now();
    }
  }
  
  void updateAction(String id) {
    final room = _rooms[id];
    if (room != null) {
      room.lastActionAt = DateTime.now();
      if (room.state == GameState.timeout) {
        room.state = GameState.playing;
      }
    }
  }
  
  void checkTimeout(String id) {
    final room = _rooms[id];
    if (room == null) return;
    if (room.state != GameState.playing) return;
    
    if (room.lastActionAt != null) {
      final elapsed = DateTime.now().difference(room.lastActionAt!).inSeconds;
      if (elapsed > timeoutSeconds) {
        room.state = GameState.timeout;
      }
    }
  }
  
  bool isInTimeout(String id) {
    final room = _rooms[id];
    return room?.state == GameState.timeout;
  }
  
  void endGame(String id) {
    final room = _rooms[id];
    if (room != null) {
      room.state = GameState.finished;
    }
  }
  
  void addAIHost(String id, GamePlayer ai) {
    final room = _rooms[id];
    if (room != null) {
      room.aiHost = ai;
    }
  }
  
  List<GameRoom> get activeRooms => 
    _rooms.values.where((r) => r.state == GameState.playing || r.state == GameState.timeout).toList();
}

void main() {
  group('L1-09 游戏托管测试', () {
    
    test('测试1：创建游戏房间', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      
      expect(manager.getRoom('room1'), isNotNull);
      expect(manager.getRoom('room1')?.state, GameState.waiting);
    });
    
    test('测试2：开始游戏', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.startGame('room1');
      
      expect(manager.getRoom('room1')?.state, GameState.playing);
      expect(manager.getRoom('room1')?.startedAt, isNotNull);
    });
    
    test('测试3：更新最后操作时间', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.startGame('room1');
      
      final firstUpdate = manager.getRoom('room1')?.lastActionAt;
      manager.updateAction('room1');
      
      expect(manager.getRoom('room1')?.lastActionAt, isNotNull);
    });
    
    test('测试4：超时检测', () {
      final manager = GameTimeoutManager(timeoutSeconds: 0);
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.startGame('room1');
      manager.updateAction('room1');
      manager.checkTimeout('room1');
      
      expect(manager.isInTimeout('room1'), true);
    });
    
    test('测试5：超时后恢复', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.startGame('room1');
      
      // 模拟超时
      manager.getRoom('room1')?.lastActionAt = DateTime.now().subtract(Duration(seconds: 60));
      manager.checkTimeout('room1');
      
      // 恢复
      manager.updateAction('room1');
      expect(manager.getRoom('room1')?.state, GameState.playing);
    });
    
    test('测试6：添加AI托管', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.addAIHost('room1', GamePlayer(id: 'ai', name: 'AI'));
      
      expect(manager.getRoom('room1')?.aiHost, isNotNull);
      expect(manager.getRoom('room1')?.aiHost?.name, 'AI');
    });
    
    test('测试7：结束游戏', () {
      final manager = GameTimeoutManager();
      final players = [GamePlayer(id: 'p1', name: '玩家1')];
      manager.createRoom('room1', GameType.twentyFour, players);
      manager.startGame('room1');
      manager.endGame('room1');
      
      expect(manager.getRoom('room1')?.state, GameState.finished);
    });
    
    test('测试8：玩家离线标记', () {
      final player = GamePlayer(id: 'p1', name: '玩家1', isOnline: false);
      expect(player.isOnline, false);
    });
    
    test('测试9：玩家分数', () {
      final player = GamePlayer(id: 'p1', name: '玩家1', score: 100);
      expect(player.score, 100);
    });
    
    test('测试10：获取活跃房间', () {
      final manager = GameTimeoutManager();
      final players1 = [GamePlayer(id: 'p1', name: '玩家1')];
      final players2 = [GamePlayer(id: 'p2', name: '玩家2')];
      
      manager.createRoom('room1', GameType.twentyFour, players1);
      manager.createRoom('room2', GameType.poker, players2);
      manager.startGame('room1');
      manager.startGame('room2');
      manager.endGame('room1');
      
      final active = manager.activeRooms;
      expect(active.length, 1);
    });
  });
}
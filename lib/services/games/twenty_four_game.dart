// 24点游戏服务
//
// 经典24点纸牌游戏：用4个数字通过加减乘除得到24

import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import 'twenty_four_score.dart';  // 记分服务

/// 游戏状态
enum GameState {
  waiting,    // 等待玩家
  playing,    // 游戏中
  rushing,    // 抢答中
  finished,   // 已结束
}

/// 玩家信息
class GamePlayer {
  final String id;
  final String name;
  final bool isBot;
  int score;

  GamePlayer({
    required this.id,
    required this.name,
    this.isBot = false,
    this.score = 0,
  });
}

/// 游戏房间
class GameRoom {
  final String id;
  final String name;
  final List<GamePlayer> players;
  final int maxPlayers;
  GameState state;
  DateTime createdAt;
  String? winnerId;
  String? winnerAnswer;
  String? rushingPlayerId;

  GameRoom({
    required this.id,
    required this.name,
    required this.players,
    this.maxPlayers = 4,
    this.state = GameState.waiting,
    required this.createdAt,
    this.winnerId,
    this.winnerAnswer,
    this.rushingPlayerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'players': players.map((p) => {
      'id': p.id,
      'name': p.name,
      'isBot': p.isBot,
      'score': p.score,
    }).toList(),
    'maxPlayers': maxPlayers,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
    'winnerId': winnerId,
    'winnerAnswer': winnerAnswer,
    'rushingPlayerId': rushingPlayerId,
  };
}

/// 24点游戏服务
class TwentyFourGameService {
  final Logger _logger = Logger();
  final Random _random = Random();
  
  // 记分服务
  final TwentyFourScoreService _scoreService = TwentyFourScoreService();
  
  // 当前题目
  List<int> _currentNumbers = [];
  final int _targetNumber = 24;
  
  // 当前答案（机器人计算）
  String? _botAnswer;
  
  // 当前房间
  GameRoom? _currentRoom;
  String? _currentPlayerId;
  
  // 游戏配置
  int _botDelaySeconds = 90;  // 机器人让时，默认90秒
  int _rushTimeSeconds = 30;  // 抢答后输入时间，默认30秒
  
  // 计时器
  Timer? _gameTimer;
  int _timeLeft = 60;
  
  // 流控制器
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  final _timerController = StreamController<int>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  
  /// 状态变化流
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;
  
  /// 计时器流
  Stream<int> get timerStream => _timerController.stream;
  
  /// 消息流
  Stream<String> get messageStream => _messageController.stream;
  
  /// 当前数字
  List<int> get currentNumbers => _currentNumbers;
  
  /// 当前房间
  GameRoom? get currentRoom => _currentRoom;
  
  /// 剩余时间
  int get timeLeft => _timeLeft;
  
  /// 机器人让时
  int get botDelaySeconds => _botDelaySeconds;
  set botDelaySeconds(int value) => _botDelaySeconds = value;
  
  /// 抢答时间
  int get rushTimeSeconds => _rushTimeSeconds;
  set rushTimeSeconds(int value) => _rushTimeSeconds = value;
  
  /// 当前玩家ID
  String? get currentUserId => _currentPlayerId;
  
  /// 初始化玩家
  void initPlayer({
    required String playerId,
    required String playerName,
    bool isBot = false,
  }) {
    _currentPlayerId = playerId;
    _logger.i('24点游戏初始化: $playerName');
  }
  
  /// 创建游戏房间
  GameRoom createRoom(String name, {int maxPlayers = 4}) {
    final roomId = 'game_${DateTime.now().millisecondsSinceEpoch}';
    
    final room = GameRoom(
      id: roomId,
      name: name,
      players: [],
      maxPlayers: maxPlayers,
      createdAt: DateTime.now(),
    );
    
    _currentRoom = room;
    _logger.i('创建游戏房间: $name');
    return room;
  }
  
  /// 加入房间
  bool joinRoom(GamePlayer player) {
    if (_currentRoom == null) return false;
    if (_currentRoom!.players.length >= _currentRoom!.maxPlayers) return false;
    
    _currentRoom!.players.add(player);
    _notifyState();
    _logger.i('${player.name} 加入房间');
    return true;
  }
  
  /// 添加机器人
  void addBot() {
    if (_currentRoom == null) return;
    
    final botCount = _currentRoom!.players.where((p) => p.isBot).length;
    final bot = GamePlayer(
      id: 'bot_$botCount',
      name: '机器人${botCount + 1}',
      isBot: true,
    );
    
    joinRoom(bot);
  }
  
  /// 开始游戏
  void startGame() {
    if (_currentRoom == null) return;
    if (_currentRoom!.players.isEmpty) return;
    
    _currentRoom!.state = GameState.playing;
    _currentRoom!.winnerId = null;
    _currentRoom!.winnerAnswer = null;
    _currentRoom!.rushingPlayerId = null;
    _generateNumbers();
    _startTimer();
    
    _notifyState();
    _logger.i('游戏开始，题目: $_currentNumbers');
    
    // 启动机器人答题逻辑（延迟 _botDelaySeconds 秒）
    _startBotAnswering();
  }
  
  /// 生成4个数字
  void _generateNumbers() {
    _currentNumbers = [];
    for (int i = 0; i < 4; i++) {
      _currentNumbers.add(_random.nextInt(13) + 1);
    }
    
    // 预计算一个答案
    _botAnswer = _findSolution(_currentNumbers);
    
    // 如果没有解，重新生成
    if (_botAnswer == null) {
      _generateNumbers();
    }
  }
  
  /// 查找24点解法
  String? _findSolution(List<int> nums) {
    final ops = ['+', '-', '*', '/'];
    
    for (var op1 in ops) {
      for (var op2 in ops) {
        for (var op3 in ops) {
          final expressions = [
            '((${nums[0]} $op1 ${nums[1]}) $op2 ${nums[2]}) $op3 ${nums[3]}',
            '(${nums[0]} $op1 (${nums[1]} $op2 ${nums[2]})) $op3 ${nums[3]}',
            '(${nums[0]} $op1 ${nums[1]}) $op2 (${nums[2]} $op3 ${nums[3]})',
            '${nums[0]} $op1 ((${nums[1]} $op2 ${nums[2]}) $op3 ${nums[3]})',
            '${nums[0]} $op1 (${nums[1]} $op2 (${nums[2]} $op3 ${nums[3]}))',
          ];
          
          for (var expr in expressions) {
            try {
              if (_evaluateExpression(expr) == 24) {
                return expr;
              }
            } catch (_) {}
          }
        }
      }
    }
    
    return null;
  }
  
  /// 开始计时
  void _startTimer() {
    _timeLeft = 60 + _botDelaySeconds;  // 基础60秒 + 机器人让时
    _gameTimer?.cancel();
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeLeft--;
      _timerController.add(_timeLeft);
      
      if (_timeLeft <= 0) {
        _endGame(winnerId: null, answer: null);
      }
    });
  }
  
  /// 开始抢答计时
  void _startRushTimer() {
    _gameTimer?.cancel();
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeLeft--;
      _timerController.add(_timeLeft);
      
      if (_timeLeft <= 0) {
        // 抢答超时
        _messageController.add('⏰ 抢答超时！答题机会作废');
        _currentRoom!.state = GameState.playing;
        _currentRoom!.rushingPlayerId = null;
        _startTimer();  // 恢复正常计时
        _notifyState();
      }
    });
  }
  
  /// 抢答
  bool rush() {
    if (_currentRoom?.state != GameState.playing) return false;
    
    _currentRoom!.state = GameState.rushing;
    _currentRoom!.rushingPlayerId = _currentPlayerId;
    _timeLeft = _rushTimeSeconds;  // 使用配置的抢答时间
    _startRushTimer();
    
    _messageController.add('🎯 你抢到了！${_rushTimeSeconds}秒内输入答案');
    _notifyState();
    
    return true;
  }
  
  /// 启动机器人答题逻辑
  void _startBotAnswering() {
    for (final player in _currentRoom?.players ?? []) {
      if (player.isBot) {
        // 机器人等待让时后再开始抢答
        Future.delayed(Duration(seconds: _botDelaySeconds), () {
          if (_currentRoom?.state != GameState.playing) return;
          
          // 机器人抢答
          _currentRoom!.state = GameState.rushing;
          _currentRoom!.rushingPlayerId = player.id;
          _timeLeft = _rushTimeSeconds;
          _startRushTimer();
          
          // 机器人1-3秒内回答
          Future.delayed(Duration(seconds: _random.nextInt(2) + 1), () {
            if (_currentRoom?.rushingPlayerId != player.id) return;
            if (_currentRoom?.state != GameState.rushing) return;
            
            // 机器人有80%概率答对
            if (_random.nextDouble() < 0.8 && _botAnswer != null) {
              _endGame(winnerId: player.id, answer: _botAnswer);
            } else {
              _messageController.add('❌ ${player.name} 答错了！');
              _currentRoom!.state = GameState.playing;
              _currentRoom!.rushingPlayerId = null;
              _startTimer();
              _notifyState();
              
              // 重新启动机器人答题逻辑，让机器人可以再次抢答
              _startBotAnswering();
            }
          });
          
          _notifyState();
        });
      }
    }
  }
  
  /// 提交答案
  /// 返回: null=验证失败, true=正确, false=错误但继续
  bool? submitAnswer(String expression) {
    if (_currentRoom?.state != GameState.rushing) return null;
    if (_currentRoom?.rushingPlayerId != _currentPlayerId) return null;
    
    try {
      // 验证表达式
      if (!_validateExpression(expression)) {
        _messageController.add('⚠️ 表达式无效！请使用正确的4个数字');
        return null;
      }
      
      // 计算结果
      final result = _evaluateExpression(expression);
      
      if (result == _targetNumber) {
        _endGame(winnerId: _currentPlayerId, answer: expression);
        return true;
      } else {
        _messageController.add('❌ 结果是 ${result.toStringAsFixed(1)}，不等于24！');
        return false;
      }
    } catch (e) {
      _messageController.add('⚠️ 表达式格式错误: $e');
      return null;
    }
  }
  
  /// 验证表达式
  bool _validateExpression(String expr) {
    final numbers = RegExp(r'\d+')
        .allMatches(expr)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    
    if (numbers.length != 4) return false;
    
    final sortedInput = numbers..sort();
    final sortedTarget = List<int>.from(_currentNumbers)..sort();
    
    for (int i = 0; i < 4; i++) {
      if (sortedInput[i] != sortedTarget[i]) return false;
    }
    
    return true;
  }
  
  /// 计算表达式结果
  num _evaluateExpression(String expr) {
    String normalized = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('x', '*')
        .replaceAll('X', '*');
    
    return _simpleEval(normalized);
  }
  
  /// 简单表达式求值
  num _simpleEval(String expr) {
    while (expr.contains('(')) {
      final start = expr.lastIndexOf('(');
      final end = expr.indexOf(')', start);
      if (end == -1) break;
      
      final subExpr = expr.substring(start + 1, end);
      final result = _evalWithoutParens(subExpr);
      expr = expr.substring(0, start) + result.toString() + expr.substring(end + 1);
    }
    
    return _evalWithoutParens(expr);
  }
  
  /// 计算无括号表达式
  num _evalWithoutParens(String expr) {
    List<String> tokens = expr
        .replaceAll('+', ' + ')
        .replaceAll('-', ' - ')
        .replaceAll('*', ' * ')
        .replaceAll('/', ' / ')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    
    List<dynamic> processed = [];
    for (int i = 0; i < tokens.length; i++) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        final left = processed.removeLast() as num;
        final right = num.parse(tokens[++i]);
        if (tokens[i - 1] == '*') {
          processed.add(left * right);
        } else {
          processed.add(left / right);
        }
      } else if (tokens[i] != '+' && tokens[i] != '-') {
        processed.add(num.parse(tokens[i]));
      } else {
        processed.add(tokens[i]);
      }
    }
    
    num result = processed[0] as num;
    for (int i = 1; i < processed.length; i += 2) {
      final op = processed[i] as String;
      final num_ = processed[i + 1] as num;
      if (op == '+') {
        result += num_;
      } else {
        result -= num_;
      }
    }
    
    return result;
  }
  
  /// 结束游戏
  void _endGame({String? winnerId, String? answer}) async {
    _gameTimer?.cancel();
    _currentRoom!.state = GameState.finished;
    _currentRoom!.winnerId = winnerId;
    _currentRoom!.winnerAnswer = answer;
    
    // 初始化记分服务
    await _scoreService.initialize();
    
    if (winnerId != null) {
      // 使用 firstWhere 的 orElse 参数避免抛出异常
      final winner = _currentRoom?.players.firstWhere(
        (p) => p.id == winnerId,
        orElse: () => _currentRoom!.players.first,  // 找不到时返回第一个玩家
      );
      if (winner != null) {
        winner.score++;
        _logger.i('${winner.name} 获胜！答案: $answer');
        
        // 记录游戏结果
        await _scoreService.recordGame(
          playerId: winner.id,
          playerName: winner.name,
          isWin: true,
          answer: answer,
        );
        
        if (answer != null) {
          final stats = _scoreService.getPlayerStats(winner.id);
          _messageController.add('🎉 ${winner.name} 获胜！\n答案: $answer = 24\n\n$stats');
        }
      }
    } else {
      // 记录所有玩家的失败
      for (final player in _currentRoom?.players ?? []) {
        if (!player.isBot) {
          await _scoreService.recordGame(
            playerId: player.id,
            playerName: player.name,
            isWin: false,
          );
        }
      }
      _messageController.add('⏰ 时间到！无人答对');
    }
    
    _notifyState();
  }
  
  /// 下一题（连续游戏）
  void nextRound() {
    if (_currentRoom == null) return;
    
    _gameTimer?.cancel();
    _currentRoom!.state = GameState.playing;
    _currentRoom!.winnerId = null;
    _currentRoom!.winnerAnswer = null;
    _currentRoom!.rushingPlayerId = null;
    _generateNumbers();
    _startTimer();
    
    // 重新启动机器人答题逻辑
    _startBotAnswering();
    
    _messageController.add('📢 下一题！');
    _notifyState();
    
    _logger.i('下一题开始: $_currentNumbers');
  }
  
  /// 退出游戏
  void exitGame() {
    _gameTimer?.cancel();
    _currentRoom?.state = GameState.waiting;
    _currentRoom?.winnerId = null;
    _currentRoom?.winnerAnswer = null;
    _currentRoom?.rushingPlayerId = null;
    _currentNumbers = [];
    _timeLeft = 60 + _botDelaySeconds;
    
    _notifyState();
  }
  
  /// 重新开始
  void restart() {
    _gameTimer?.cancel();
    _currentRoom?.state = GameState.waiting;
    _currentRoom?.winnerId = null;
    _currentRoom?.winnerAnswer = null;
    _currentRoom?.rushingPlayerId = null;
    _currentNumbers = [];
    _timeLeft = 60 + _botDelaySeconds;
    
    _notifyState();
  }
  
  /// 通知状态变化
  void _notifyState() {
    _stateController.add({
      'room': _currentRoom,
      'numbers': _currentNumbers,
      'timeLeft': _timeLeft,
      'botDelay': _botDelaySeconds,
      'rushTime': _rushTimeSeconds,
    });
  }
  
  /// 清理资源
  void dispose() {
    _gameTimer?.cancel();
    _stateController.close();
    _timerController.close();
    _messageController.close();
  }
}

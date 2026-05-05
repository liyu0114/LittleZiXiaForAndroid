// 24点联网对战屏幕 - 主机权威架构
//
// 架构说明：
// - 主机：运行游戏逻辑，每秒广播状态
// - 客户端：只显示状态，操作发送给主机

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/games/twenty_four_game.dart';
import '../services/games/network_game_service.dart';

class NetworkGameScreen extends StatefulWidget {
  const NetworkGameScreen({super.key});

  @override
  State<NetworkGameScreen> createState() => _NetworkGameScreenState();
}

class _NetworkGameScreenState extends State<NetworkGameScreen> {
  // 网络服务
  NetworkGameService? _networkService;
  
  // 游戏服务（仅主机使用）
  TwentyFourGameService? _gameService;
  
  // 游戏状态
  Map<String, dynamic> _gameState = {};
  
  // 网络状态
  bool _isHost = false;
  bool _isConnected = false;
  int _lastBroadcastTime = 0;  // 上次广播时间（用于节流）
  
  // 本地玩家信息
  String? _localPlayerId;
  String _localPlayerName = '玩家';
  
  // 表达式输入
  String _expression = '';
  
  // 配置选项
  final int _botDelay = 90;
  final int _rushTime = 30;

  @override
  void initState() {
    super.initState();
    _localPlayerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _gameService?.dispose();
    _networkService?.dispose();
    super.dispose();
  }

  /// 创建房间（成为主机）
  void _createRoom(String roomName) async {
    _isHost = true;
    _isConnected = true;
    
    // 初始化网络服务
    _networkService = NetworkGameService();
    await _networkService!.initAsHost(
      playerId: _localPlayerId!,
      playerName: _localPlayerName,
      port: 18791,
    );
    
    // 初始化游戏服务
    _gameService = TwentyFourGameService();
    _gameService!.initPlayer(
      playerId: _localPlayerId!,
      playerName: _localPlayerName,
    );
    _gameService!.botDelaySeconds = _botDelay;
    _gameService!.rushTimeSeconds = _rushTime;
    
    // 创建房间
    final room = _gameService!.createRoom(roomName);
    _gameService!.joinRoom(GamePlayer(
      id: _localPlayerId!,
      name: _localPlayerName,
    ));
    
    // 监听游戏状态变化
    _gameService!.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _gameState = state;
        });
      }
    });
    
    // 监听计时器
    _gameService!.timerStream.listen((time) {
      if (mounted) {
        setState(() {
          _gameState['timeLeft'] = time;
        });
        
        // 节流：每2秒广播一次状态（而不是每秒）
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastBroadcastTime >= 2000) {
          _broadcastGameState();
          _lastBroadcastTime = now;
        }
      }
    });
    
    // 监听消息
    _gameService!.messageStream.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });
    
    // 监听网络消息（来自客户端的操作）
    _networkService!.stateStream.listen((data) {
      _handleNetworkAction(data);
    });
    
    setState(() {
      _gameState = {
        'room': room,
        'numbers': [],
        'timeLeft': 60 + _botDelay,
      };
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('房间已创建，等待其他玩家加入...')),
    );
  }

  /// 加入房间（成为客户端）
  void _joinRoom(String hostIp) async {
    _isHost = false;
    
    _networkService = NetworkGameService();
    
    final success = await _networkService!.connectToHost(
      playerId: _localPlayerId!,
      playerName: _localPlayerName,
      ipAddress: hostIp,
      port: 18791,
    );
    
    if (success) {
      setState(() {
        _isConnected = true;
      });
      
      // 监听主机发来的游戏状态
      _networkService!.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _gameState = state;
          });
        }
      });
      
      // 监听网络消息
      _networkService!.messageStream.listen((msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 $hostIp')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('连接失败')),
      );
    }
  }

  /// 处理网络操作（主机）
  void _handleNetworkAction(Map<String, dynamic> data) {
    if (!_isHost || _gameService == null) return;
    
    final action = data['action'];
    
    switch (action) {
      case 'playerJoined':
        _gameService!.joinRoom(GamePlayer(
          id: data['playerId'],
          name: data['playerName'],
          isBot: false,
        ));
        _broadcastPlayerList();
        break;
        
      case 'rush':
        _handleRemoteRush(data['playerId'], data['playerName']);
        break;
        
      case 'submitAnswer':
        _handleRemoteAnswer(data['playerId'], data['playerName'], data['answer']);
        break;
        
      case 'addBot':
        _gameService!.addBot();
        _broadcastPlayerList();
        break;
        
      case 'startGame':
        _startGame();
        break;
    }
  }

  /// 处理远程抢答（主机）
  void _handleRemoteRush(String playerId, String playerName) {
    if (_gameService?.currentRoom?.state != GameState.playing) return;
    
    final originalId = _gameService!.currentUserId;
    _gameService!.initPlayer(playerId: playerId, playerName: playerName);
    
    if (_gameService!.rush()) {
      _broadcastGameState();
    }
    
    if (originalId != null) {
      _gameService!.initPlayer(playerId: originalId, playerName: _localPlayerName);
    }
  }

  /// 处理远程答案（主机）
  void _handleRemoteAnswer(String playerId, String playerName, String answer) {
    if (_gameService?.currentRoom?.state != GameState.rushing) return;
    if (_gameService?.currentRoom?.rushingPlayerId != playerId) return;
    
    final originalId = _gameService!.currentUserId;
    _gameService!.initPlayer(playerId: playerId, playerName: playerName);
    
    _gameService!.submitAnswer(answer);
    
    if (originalId != null) {
      _gameService!.initPlayer(playerId: originalId, playerName: _localPlayerName);
    }
    
    _broadcastGameState();
  }

  /// 广播游戏状态（主机）
  void _broadcastGameState() {
    if (!_isHost || _networkService == null) return;
    
    final room = _gameService?.currentRoom;
    final state = {
      'room': room?.toJson(),
      'numbers': _gameService?.currentNumbers ?? [],
      'timeLeft': _gameService?.timeLeft ?? 60,
      'botDelay': _botDelay,
      'rushTime': _rushTime,
    };
    
    _networkService!.broadcastGameState(state);
  }

  /// 广播玩家列表（主机）
  void _broadcastPlayerList() {
    if (!_isHost || _networkService == null) return;
    
    final players = _gameService?.currentRoom?.players.map((p) => {
      'id': p.id,
      'name': p.name,
      'isBot': p.isBot,
      'score': p.score,
    }).toList() ?? [];
    
    _networkService!.broadcastPlayerList(players);
  }

  /// 开始游戏（主机）
  void _startGame() {
    if (!_isHost || _gameService == null) return;
    
    _expression = '';
    _gameService!.startGame();
    _broadcastGameState();
  }

  /// 抢答
  void _rush() {
    if (_isHost && _gameService != null) {
      _gameService!.rush();
      _broadcastGameState();
    } else if (_networkService != null) {
      _networkService!.sendRush();
    }
    
    setState(() {
      _expression = '';
    });
  }

  /// 提交答案
  void _submitAnswer() {
    if (_expression.isEmpty) return;
    
    if (_isHost && _gameService != null) {
      _gameService!.submitAnswer(_expression);
      _broadcastGameState();
    } else if (_networkService != null) {
      _networkService!.sendAnswer(_expression);
    }
    
    setState(() {
      _expression = '';
    });
  }

  /// 添加机器人
  void _addBot() {
    if (_isHost && _gameService != null) {
      _gameService!.addBot();
      _broadcastPlayerList();
    } else if (_networkService != null) {
      _networkService!.requestAddBot();
    }
  }

  /// 下一题（主机）
  void _nextRound() {
    if (!_isHost || _gameService == null) return;
    
    _expression = '';
    _gameService!.nextRound();
    _broadcastGameState();
  }

  /// 按键处理
  void _onKeyPress(String key) {
    setState(() {
      if (key == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (key == 'CLR') {
        _expression = '';
      } else {
        _expression += key;
      }
    });
  }

  void _showJoinDialog() {
    final ipController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入游戏'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入主机的 IP 地址'),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: '主机 IP',
                hintText: '例如: 100.120.127.105',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context);
                _joinRoom(ip);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  /// 显示创建房间对话框
  void _showCreateRoomDialog() {
    final roomNameController = TextEditingController(text: '龙虾的房间');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建房间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomNameController,
              decoration: const InputDecoration(
                labelText: '房间名称',
                hintText: '给你的房间起个名字',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _createRoom(roomNameController.text.trim().isEmpty 
                  ? '龙虾的房间' 
                  : roomNameController.text.trim());
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _gameState['room'];
    final numbers = _gameState['numbers'] as List? ?? [];
    final timeLeft = _gameState['timeLeft'] as int? ?? 60;
    
    // 解析房间状态
    GameState gameState = GameState.waiting;
    if (room != null && room is GameRoom) {
      gameState = room.state;
    } else if (room != null && room is Map) {
      final stateStr = room['state'] as String?;
      if (stateStr != null) {
        gameState = GameState.values.firstWhere(
          (e) => e.name == stateStr,
          orElse: () => GameState.waiting,
        );
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('联网24点'),
        actions: [
          if (_isConnected)
            Chip(
              label: Text(_isHost ? '主机' : '已连接'),
              backgroundColor: _isHost ? Colors.green : Colors.blue,
            ),
        ],
      ),
      body: room == null
          ? _buildLobby()
          : gameState == GameState.waiting
              ? _buildWaitingRoom(room)
              : _buildGameView(room, numbers, timeLeft, gameState),
    );
  }

  Widget _buildLobby() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('联网24点', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(
              '通过 Tailscale 与朋友一起玩24点',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add),
              label: const Text('创建房间'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showJoinDialog,
              icon: const Icon(Icons.link),
              label: const Text('加入房间'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingRoom(dynamic room) {
    List<dynamic> players = [];
    if (room is GameRoom) {
      players = room.players;
    } else if (room is Map) {
      players = room['players'] ?? [];
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('房间: ${room is GameRoom ? room.name : room['name'] ?? '联网24点'}', 
                           style: Theme.of(context).textTheme.titleLarge),
                      Chip(
                        label: Text('${players.length}/4'),
                        backgroundColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('机器人让时: ${_botDelay}秒'),
                  Text('抢答时间: ${_rushTime}秒'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Text('玩家列表', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final name = player is GamePlayer ? player.name : player['name'] ?? 'Unknown';
                final isBot = player is GamePlayer ? player.isBot : player['isBot'] ?? false;
                final score = player is GamePlayer ? player.score : player['score'] ?? 0;
                
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(isBot ? Icons.smart_toy : Icons.person),
                  ),
                  title: Text(name),
                  trailing: Text('得分: $score'),
                );
              },
            ),
          ),
          
          if (_isHost) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addBot,
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('添加机器人'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: players.length >= 2 ? _startGame : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始游戏'),
                  ),
                ),
              ],
            ),
          ] else
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '等待主机开始游戏...',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameView(dynamic room, List numbers, int timeLeft, GameState gameState) {
    final isRushing = gameState == GameState.rushing;
    final isFinished = gameState == GameState.finished;
    
    // 获取抢答玩家 ID
    String? rushingPlayerId;
    if (room is GameRoom) {
      rushingPlayerId = room.rushingPlayerId;
    } else if (room is Map) {
      rushingPlayerId = room['rushingPlayerId'];
    }
    
    final isMyRush = rushingPlayerId == _localPlayerId;
    
    // 获取获胜者信息
    String? winnerId;
    String? winnerAnswer;
    if (room is GameRoom) {
      winnerId = room.winnerId;
      winnerAnswer = room.winnerAnswer;
    } else if (room is Map) {
      winnerId = room['winnerId'];
      winnerAnswer = room['winnerAnswer'];
    }
    
    // 获取玩家列表
    List<dynamic> players = [];
    if (room is GameRoom) {
      players = room.players;
    } else if (room is Map) {
      players = room['players'] ?? [];
    }
    
    return Column(
      children: [
        // 计时器
        Container(
          padding: const EdgeInsets.all(12),
          color: isRushing ? Colors.orange.shade100 : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer, color: timeLeft <= 10 ? Colors.red : null),
                  const SizedBox(width: 8),
                  Text(
                    isRushing ? '抢答: $timeLeft 秒' : '剩余: $timeLeft 秒',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: timeLeft <= 10 ? Colors.red : null,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('目标: 24', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // 数字卡片
        if (numbers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: numbers.map((n) => _buildNumberCard(n as int)).toList(),
            ),
          ),
        
        // 表达式显示 - 只有自己抢答成功时才显示
        if (!isFinished && isRushing && isMyRush)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _expression.isEmpty ? '请输入表达式' : _expression,
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'monospace',
                color: _expression.isEmpty ? Colors.grey : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        // 自定义小键盘
        if (!isFinished && isRushing && isMyRush)
          Expanded(
            child: _buildKeypad(numbers),
          ),
        
        // 抢答按钮
        if (gameState == GameState.playing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _rush,
                icon: const Icon(Icons.pan_tool, size: 28),
                label: const Text('抢答！', style: TextStyle(fontSize: 20)),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ),
        
        // 获胜者信息 + 下一题按钮
        if (isFinished)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: winnerId != null ? Colors.green.shade100 : Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 有人获胜
                    if (winnerId != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            '${_getPlayerName(players, winnerId)} 获胜！',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (winnerAnswer != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '答案: $winnerAnswer = 24',
                          style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                        ),
                      ],
                    ] else ...[
                      // 没人答对
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_off, color: Colors.orange, size: 32),
                          const SizedBox(width: 8),
                          const Text(
                            '时间到！无人答对',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // 下一题按钮（主机/单机）
                    if (_isHost)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _nextRound,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('新题目'),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '等待主机出下一题...',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getPlayerName(List<dynamic> players, String? playerId) {
    if (playerId == null) return 'Unknown';
    
    for (final player in players) {
      final id = player is GamePlayer ? player.id : player['id'];
      if (id == playerId) {
        return player is GamePlayer ? player.name : player['name'] ?? 'Unknown';
      }
    }
    
    return 'Unknown';
  }

  Widget _buildNumberCard(int number) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 70,
        height: 90,
        alignment: Alignment.center,
        child: Text('$number', 
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKeypad(List numbers) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: numbers.map((n) => _buildKey('$n')).toList(),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKey('+'), _buildKey('-'), _buildKey('×'), _buildKey('÷'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKey('('), _buildKey(')'),
                _buildKey('DEL', isAction: true), _buildKey('CLR', isAction: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _expression.isNotEmpty ? _submitAnswer : null,
                child: const Text('提交答案', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, {bool isAction = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton(
          onPressed: () => _onKeyPress(label),
          style: FilledButton.styleFrom(
            backgroundColor: isAction ? Colors.grey.shade700 : null,
            padding: EdgeInsets.zero,
          ),
          child: Text(label, 
              style: TextStyle(fontSize: label.length > 1 ? 16 : 24)),
        ),
      ),
    );
  }
}

// 24点游戏屏幕
//
// 玩24点游戏 - 改进版：抢答机制 + 自定义小键盘 + 可配置

import 'package:flutter/material.dart';
import '../services/games/twenty_four_game.dart';
import 'network_game_screen.dart';
import 'network_game_screen.dart';

class TwentyFourGameScreen extends StatefulWidget {
  const TwentyFourGameScreen({super.key});

  @override
  State<TwentyFourGameScreen> createState() => _TwentyFourGameScreenState();
}

class _TwentyFourGameScreenState extends State<TwentyFourGameScreen> {
  final TwentyFourGameService _gameService = TwentyFourGameService();
  
  GameRoom? _room;
  List<int> _numbers = [];
  int _timeLeft = 60;
  String? _message;
  String _expression = '';
  
  // 配置选项
  int _botDelay = 90;  // 机器人让时
  int _rushTime = 30;  // 抢答时间
  
  @override
  void initState() {
    super.initState();
    _initGame();
  }
  
  void _initGame() {
    _gameService.initPlayer(
      playerId: 'player_${DateTime.now().millisecondsSinceEpoch}',
      playerName: '玩家',
    );
    
    // 应用配置
    _gameService.botDelaySeconds = _botDelay;
    _gameService.rushTimeSeconds = _rushTime;
    
    // 监听状态
    _gameService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _room = state['room'];
          _numbers = state['numbers'] ?? [];
          _timeLeft = state['timeLeft'] ?? 60;
        });
      }
    });
    
    // 监听计时器
    _gameService.timerStream.listen((time) {
      if (mounted) {
        setState(() {
          _timeLeft = time;
        });
      }
    });
    
    // 监听消息
    _gameService.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _message = msg;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }
  
  void _createRoom() {
    final room = _gameService.createRoom('24点对战');
    
    _gameService.joinRoom(GamePlayer(
      id: 'player_${DateTime.now().millisecondsSinceEpoch}',
      name: '玩家',
    ));
    
    setState(() {
      _room = room;
    });
  }
  
  void _addBot() {
    _gameService.addBot();
  }
  
  void _startGame() {
    _expression = '';
    _message = null;
    // 应用最新配置
    _gameService.botDelaySeconds = _botDelay;
    _gameService.rushTimeSeconds = _rushTime;
    _gameService.startGame();
  }
  
  void _rush() {
    _expression = '';
    _gameService.rush();
  }
  
  void _submitAnswer() {
    final result = _gameService.submitAnswer(_expression);
    if (result == true) {
      setState(() {
        _message = '🎉 正确！';
      });
    }
  }
  
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
  
  void _restart() {
    _expression = '';
    _message = null;
    _gameService.restart();
  }
  
  void _exitGame() {
    _expression = '';
    _message = null;
    _gameService.exitGame();
    setState(() {
      _room = null;
    });
  }
  
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('游戏设置', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              
              // 机器人让时
              Text('机器人让时: ${_botDelay}秒'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [30, 60, 90, 120, 150, 180].map((s) => 
                  ChoiceChip(
                    label: Text('${s}秒'),
                    selected: _botDelay == s,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => _botDelay = s);
                        setState(() => _botDelay = s);
                      }
                    },
                  ),
                ).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // 抢答时间
              Text('抢答输入时间: ${_rushTime}秒'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 20, 30, 45, 60].map((s) => 
                  ChoiceChip(
                    label: Text('${s}秒'),
                    selected: _rushTime == s,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => _rushTime = s);
                        setState(() => _rushTime = s);
                      }
                    },
                  ),
                ).toList(),
              ),
              
              const SizedBox(height: 24),
              
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('24点游戏'),
        actions: [
          if (_room != null) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
              tooltip: '游戏设置',
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _exitGame,
              tooltip: '退出游戏',
            ),
          ],
          if (_room?.state == GameState.finished)
            TextButton(
              onPressed: _restart,
              child: const Text('再来一局'),
            ),
        ],
      ),
      body: _room == null
          ? _buildLobby()
          : _room!.state == GameState.waiting
              ? _buildWaitingRoom()
              : _buildGameView(),
    );
  }
  
  Widget _buildLobby() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.games, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text('24点游戏', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            '用4个数字，通过加减乘除，使结果等于24',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _createRoom,
            icon: const Icon(Icons.play_arrow),
            label: const Text('单机游戏'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkGameScreen(),
                ),
              );
            },
            icon: const Icon(Icons.wifi),
            label: const Text('联网对战'),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
            label: Text('设置（机器人让${_botDelay}秒，抢答${_rushTime}秒）'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaitingRoom() {
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
                  Text('房间: ${_room!.name}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('玩家: ${_room!.players.length}/${_room!.maxPlayers}'),
                  const SizedBox(height: 4),
                  Text('机器人让时: ${_botDelay}秒', style: TextStyle(color: Colors.grey.shade600)),
                  Text('抢答时间: ${_rushTime}秒', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Text('玩家列表', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _room!.players.length,
              itemBuilder: (context, index) {
                final player = _room!.players[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(player.isBot ? Icons.smart_toy : Icons.person),
                  ),
                  title: Text(player.name),
                  trailing: Text('得分: ${player.score}'),
                );
              },
            ),
          ),
          
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
                  onPressed: _room!.players.isNotEmpty ? _startGame : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始游戏'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGameView() {
    final isRushing = _room?.state == GameState.rushing;
    final isMyRush = _room?.rushingPlayerId?.startsWith('player_') == true;
    final isFinished = _room?.state == GameState.finished;
    
    return Column(
      children: [
        // 计时器
        Container(
          padding: const EdgeInsets.all(12),
          color: isRushing 
              ? Colors.orange.shade100 
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isRushing ? Icons.timer : Icons.timer,
                    color: _timeLeft <= 10 ? Colors.red : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRushing ? '抢答: $_timeLeft 秒' : '剩余: $_timeLeft 秒',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _timeLeft <= 10 ? Colors.red : null,
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
                child: const Text('目标: 24', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // 数字卡片
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _numbers.map((num) => _buildNumberCard(num)).toList(),
          ),
        ),
        
        // 消息提示
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: _message!.contains('正确') || _message!.contains('获胜')
                  ? Colors.green.shade100
                  : _message!.contains('错误') || _message!.contains('超时') || _message!.contains('无效')
                      ? Colors.red.shade100
                      : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              ),
            ),
          ),
        
        // 表达式显示
        if (!isFinished && (isRushing || isMyRush || _expression.isNotEmpty))
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
        if (!isFinished && (isRushing && isMyRush || _room!.players.any((p) => !p.isBot && p.id.startsWith('player_'))))
          Expanded(
            child: _buildKeypad(isRushing && isMyRush),
          ),
        
        // 抢答按钮
        if (_room?.state == GameState.playing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _rush,
                icon: const Icon(Icons.pan_tool, size: 28),
                label: const Text('抢答！', style: TextStyle(fontSize: 20)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
          ),
        
        // 获胜者信息
        if (isFinished && _room?.winnerId != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.green.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                        const SizedBox(width: 8),
                        Text(
                          '${_room!.players.firstWhere((p) => p.id == _room!.winnerId).name} 获胜！',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_room!.winnerAnswer != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '答案: ${_room!.winnerAnswer} = 24',
                        style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildNumberCard(int number) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 70,
        height: 90,
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  
  Widget _buildKeypad(bool enabled) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 数字按钮
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _numbers.map((n) => _buildKey('$n', enabled)).toList(),
            ),
          ),
          // 运算符按钮
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKey('+', enabled),
                _buildKey('-', enabled),
                _buildKey('×', enabled),
                _buildKey('÷', enabled),
              ],
            ),
          ),
          // 括号和操作按钮
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKey('(', enabled),
                _buildKey(')', enabled),
                _buildKey('DEL', enabled, isAction: true),
                _buildKey('CLR', enabled, isAction: true),
              ],
            ),
          ),
          // 提交按钮
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: enabled && _expression.isNotEmpty ? _submitAnswer : null,
                child: const Text('提交答案', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKey(String label, bool enabled, {bool isAction = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton(
          onPressed: enabled ? () => _onKeyPress(label) : null,
          style: FilledButton.styleFrom(
            backgroundColor: isAction ? Colors.grey.shade700 : null,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: label.length > 1 ? 16 : 24),
          ),
        ),
      ),
    );
  }
}

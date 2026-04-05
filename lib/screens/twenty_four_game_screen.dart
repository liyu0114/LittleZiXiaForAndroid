// 24点游戏屏幕
//
// 玩24点游戏 - 改进版：抢答机制 + 自定义小键盘 + 可配置

import 'package:flutter/material.dart';
import '../services/games/twenty_four_game.dart';
import '../services/games/twenty_four_score.dart';
import 'network_game_screen.dart';

class TwentyFourGameScreen extends StatefulWidget {
  const TwentyFourGameScreen({super.key});

  @override
  State<TwentyFourGameScreen> createState() => _TwentyFourGameScreenState();
}

class _TwentyFourGameScreenState extends State<TwentyFourGameScreen> {
  final TwentyFourGameService _gameService = TwentyFourGameService();
  final TwentyFourScoreService _scoreService = TwentyFourScoreService();
  
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
  
  void _initGame() async {
    // 初始化成绩服务
    await _scoreService.initialize();
    
    _gameService.initPlayer(
      playerId: 'player_${DateTime.now().millisecondsSinceEpoch}',
      playerName: '玩家',
    );
    
    // 应用配置
    _gameService.botDelaySeconds = _botDelay;
    _gameService.rushTimeSeconds = _rushTime;
    
    // 监听状态
    _gameService.stateStream.listen((state) async {
      if (mounted) {
        setState(() {
          _room = state['room'];
          _numbers = state['numbers'] ?? [];
          _timeLeft = state['timeLeft'] ?? 60;
        });
        
        // 游戏结束时记录成绩
        if (_room?.state == GameState.finished && _room?.winnerId != null) {
          final winner = _room!.players.firstWhere(
            (p) => p.id == _room!.winnerId,
            orElse: () => _room!.players.first,
          );
          
          // 记录游戏结果
          await _scoreService.recordGame(
            playerId: winner.id,
            playerName: winner.name,
            isWin: true,
            answer: _room!.winnerAnswer,
          );
        }
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
        _message = '🎉 正确！答案正确！';
      });
    } else if (result == false) {
      setState(() {
        _message = '❌ 答案不正确，请重试！';
      });
    } else {
      setState(() {
        _message = '⚠️ 无法验证答案，请检查表达式格式';
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

  void _showSolutions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text('答案公布 (${_room!.allSolutions.length}种解法)'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _room!.allSolutions.length,
            itemBuilder: (context, index) {
              final solution = _room!.allSolutions[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '$solution = 24',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
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

  void _showScores() {
    final records = _scoreService.getAllRecords();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text('游戏排行'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: records.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_score, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无游戏记录', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0
                              ? Colors.amber
                              : index == 1
                                  ? Colors.grey.shade400
                                  : index == 2
                                      ? Colors.brown.shade300
                                      : Colors.blue.shade100,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3 ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        title: Text(record.playerName),
                        subtitle: Text(
                          '胜率: ${(record.winRate * 100).toStringAsFixed(1)}%',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${record.wins}胜 ${record.losses}负',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '总分: ${record.totalGames}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
        title: const Text('24点游戏'),
        actions: [
          // 成绩按钮（始终显示）
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: _showScores,
            tooltip: '游戏排行',
          ),
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
              : isFinished
                  ? Colors.green.shade100
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFinished ? Icons.check_circle : Icons.timer,
                    color: isFinished 
                        ? Colors.green 
                        : _timeLeft <= 10 ? Colors.red : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFinished 
                        ? '✅ 游戏结束' 
                        : isRushing 
                            ? '抢答: $_timeLeft 秒' 
                            : '剩余: $_timeLeft 秒',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isFinished 
                          ? Colors.green 
                          : _timeLeft <= 10 ? Colors.red : null,
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
        
        // 数字卡片（游戏结束时仍然显示）
        if (_numbers.isNotEmpty)
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
        
        // 表达式显示（游戏结束时显示最终答案）
        if (isFinished && _room?.winnerAnswer != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_room!.winnerAnswer} = 24',
              style: const TextStyle(
                fontSize: 28,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else if (!isFinished && (isRushing || isMyRush || _expression.isNotEmpty))
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
        
        // 自定义小键盘（只在抢答且轮到自己时显示）
        if (!isFinished && isRushing && isMyRush)
          Expanded(
            child: _buildKeypad(true),
          )
        // 如果不是抢答状态，显示空白占位
        else if (!isFinished && !isRushing)
          const Spacer(),
        
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
        
        // 获胜者信息（游戏结束时显示）
        if (isFinished)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_room?.winnerId != null) ...[
                  Card(
                    color: Colors.green.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            '${_room!.players.firstWhere((p) => p.id == _room!.winnerId, orElse: () => _room!.players.first).name} 获胜！',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    color: Colors.orange.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
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
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 查看答案按钮
                if (_room?.allSolutions.isNotEmpty == true)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _showSolutions,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text('查看答案 (${_room!.allSolutions.length}种解法)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再来一局'),
                  ),
                ),
              ],
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

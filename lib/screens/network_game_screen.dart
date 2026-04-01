// 24点联网对战屏幕
//
// 支持多设备联网玩 24 点游戏

import 'package:flutter/material.dart';
import '../services/games/twenty_four_game.dart';
import '../services/games/network_game_service.dart';
import '../services/chat/lan_discovery.dart';

class NetworkGameScreen extends StatefulWidget {
  const NetworkGameScreen({super.key});

  @override
  State<NetworkGameScreen> createState() => _NetworkGameScreenState();
}

class _NetworkGameScreenState extends State<NetworkGameScreen> {
  final TwentyFourGameService _gameService = TwentyFourGameService();
  final LanDiscoveryService _discoveryService = LanDiscoveryService();
  NetworkGameService? _networkService;
  
  GameRoom? _room;
  List<int> _numbers = [];
  int _timeLeft = 60;
  String? _message;
  String _expression = '';
  
  // 网络状态
  bool _isHost = false;
  bool _isConnected = false;
  
  // 配置选项
  final int _botDelay = 90;
  final int _rushTime = 30;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    final playerId = 'player_${DateTime.now().millisecondsSinceEpoch}';
    
    _gameService.initPlayer(
      playerId: playerId,
      playerName: '玩家',
    );
    
    _gameService.botDelaySeconds = _botDelay;
    _gameService.rushTimeSeconds = _rushTime;
    
    // 初始化发现服务
    _discoveryService.init(
      deviceId: playerId,
      deviceName: '玩家',
      isBot: false,
    );
    
    // 监听发现的设备
    _discoveryService.devicesStream.listen((devices) {
      // 可以在这里更新 UI，显示发现的设备
      // if (mounted) {
      //   setState(() {
      //     _nearbyDevices = devices;
      //   });
      // }
    });
    
    // 监听游戏状态
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
        setState(() => _timeLeft = time);
      }
    });
    
    // 监听消息
    _gameService.messageStream.listen((msg) {
      if (mounted) {
        setState(() => _message = msg);
      }
    });
  }

  void _createNetworkRoom() async {
    // 初始化网络服务
    _networkService = NetworkGameService(_gameService);
    await _networkService!.init(
      playerId: _gameService.currentUserId!,
      playerName: '玩家',
      port: 18791,
    );
    
    // 创建房间
    final room = _gameService.createRoom('联网24点');
    _gameService.joinRoom(GamePlayer(
      id: _gameService.currentUserId!,
      name: '玩家',
    ));
    
    setState(() {
      _room = room;
      _isHost = true;
      _isConnected = true;
    });
    
    // 广播房间
    _discoveryService.setCurrentRoom(room.id, room.name);
    await _discoveryService.start();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('房间已创建，等待其他玩家加入...')),
    );
  }

  void _joinNetworkRoom(String hostIp) async {
    // 初始化网络服务
    _networkService = NetworkGameService(_gameService);
    await _networkService!.init(
      playerId: _gameService.currentUserId!,
      playerName: '玩家',
      port: 18791,
    );
    
    // 连接到主机
    final success = await _networkService!.connectToHost(
      hostId: 'host_$hostIp',
      hostName: '游戏主机',
      ipAddress: hostIp,
      port: 18791,
    );
    
    if (success) {
      setState(() {
        _isHost = false;
        _isConnected = true;
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
                _joinNetworkRoom(ip);
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  void _startNetworkGame() {
    _expression = '';
    _message = null;
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
      setState(() => _message = '🎉 正确！');
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

  @override
  void dispose() {
    _gameService.dispose();
    _networkService?.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _room == null
          ? _buildLobby()
          : _room!.state == GameState.waiting
              ? _buildWaitingRoom()
              : _buildGameView(),
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
              onPressed: _createNetworkRoom,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('房间: ${_room!.name}', 
                           style: Theme.of(context).textTheme.titleLarge),
                      if (_isHost)
                        Chip(
                          label: Text('${_room!.players.length}/${_room!.maxPlayers}'),
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
          
          if (_isHost) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _gameService.addBot(),
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('添加机器人'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _room!.players.length >= 2 ? _startNetworkGame : null,
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

  Widget _buildGameView() {
    final isRushing = _room?.state == GameState.rushing;
    final isMyRush = _room?.rushingPlayerId == _gameService.currentUserId;
    final isFinished = _room?.state == GameState.finished;
    
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
                  Icon(Icons.timer, color: _timeLeft <= 10 ? Colors.red : null),
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
                child: const Text('目标: 24', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // 数字卡片
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _numbers.map((n) => _buildNumberCard(n)).toList(),
          ),
        ),
        
        // 消息提示
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: _message!.contains('正确') || _message!.contains('获胜')
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        
        // 表达式显示
        if (!isFinished && (isRushing || _expression.isNotEmpty))
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
            child: _buildKeypad(),
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
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
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
        child: Text('$number', 
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _numbers.map((n) => _buildKey('$n')).toList(),
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

/// 24点游戏界面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/games/twenty_four_game.dart';

class TwentyFourGameScreen extends StatefulWidget {
  const TwentyFourGameScreen({super.key});

  @override
  State<TwentyFourGameScreen> createState() => _TwentyFourGameScreenState();
}

class _TwentyFourGameScreenState extends State<TwentyFourGameScreen> {
  final TextEditingController _answerController = TextEditingController();
  final TwentyFourGameService _gameService = TwentyFourGameService();
  
  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('24点游戏'),
          actions: [
            IconButton(
              icon: const Icon(Icons.leaderboard),
              onPressed: () => _showStatistics(context),
              tooltip: '统计',
            ),
          ],
        ),
        body: Consumer<TwentyFourGameService>(
          builder: (context, game, child) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 分数和连胜
                  _buildScoreBoard(game),
                  
                  const SizedBox(height: 24),
                  
                  // 4张牌
                  if (game.status == GameStatus.idle)
                    _buildStartPrompt()
                  else
                    _buildCards(game.numbers),
                  
                  const SizedBox(height: 24),
                  
                  // 输入框
                  if (game.status == GameStatus.playing)
                    _buildInputArea(game)
                  else if (game.status == GameStatus.solved)
                    _buildSuccessMessage(game)
                  else if (game.status == GameStatus.failed)
                    _buildFailureMessage(game),
                  
                  const Spacer(),
                  
                  // 按钮区
                  _buildButtons(game),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// 分数板
  Widget _buildScoreBoard(TwentyFourGameService game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text(
              '得分',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${game.score}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        Column(
          children: [
            Text(
              '连胜',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: game.streak > 0 ? Colors.orange : Colors.grey,
                ),
                Text(
                  '${game.streak}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: game.streak > 0 ? Colors.orange : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
        Column(
          children: [
            Text(
              '用时',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatDuration(game.timeSpent),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ],
    );
  }
  
  /// 开始提示
  Widget _buildStartPrompt() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.calculate,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '24点游戏',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '用4张牌的数字，通过加减乘除得到24',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 4张牌
  Widget _buildCards(List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((num) => _buildCard(num)).toList(),
    );
  }
  
  /// 单张牌
  Widget _buildCard(int number) {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
  
  /// 输入区域
  Widget _buildInputArea(TwentyFourGameService game) {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          decoration: const InputDecoration(
            labelText: '输入你的答案',
            hintText: '例如: (8/(3-8/3))',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              game.submitAnswer(value);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                final hint = game.getHint();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(hint)),
                );
              },
              child: const Text('提示'),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => game.giveUp(),
              child: const Text('放弃'),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 成功消息
  Widget _buildSuccessMessage(TwentyFourGameService game) {
    return Card(
      color: Colors.green.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text(
              '正确！',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green,
                  ),
            ),
            Text(
              '你的答案: ${game.userAnswer}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '得分 +${10 + (game.streak - 1) * 2}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange,
                  ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 失败消息
  Widget _buildFailureMessage(TwentyFourGameService game) {
    return Card(
      color: Colors.red.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              game.userAnswer != null ? '错误' : '已放弃',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
            Text(
              '正确答案: ${game.solution ?? "无解"}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 按钮区
  Widget _buildButtons(TwentyFourGameService game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (game.status == GameStatus.idle)
          ElevatedButton.icon(
            onPressed: () => game.startNewGame(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始游戏'),
          ),
        if (game.status == GameStatus.playing)
          ElevatedButton.icon(
            onPressed: () {
              if (_answerController.text.isNotEmpty) {
                game.submitAnswer(_answerController.text);
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('提交'),
          ),
        if (game.status == GameStatus.solved || game.status == GameStatus.failed)
          ElevatedButton.icon(
            onPressed: () {
              _answerController.clear();
              game.startNewGame();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('下一题'),
          ),
      ],
    );
  }
  
  /// 显示统计
  void _showStatistics(BuildContext context) {
    final stats = _gameService.statistics;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('游戏统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('总场次', '${stats['totalGames']}'),
            _buildStatRow('成功', '${stats['solved']}'),
            _buildStatRow('失败', '${stats['failed']}'),
            _buildStatRow('成功率', '${((stats['successRate'] as double) * 100).toStringAsFixed(1)}%'),
            _buildStatRow('平均用时', '${(stats['averageTime'] as double).toStringAsFixed(1)}秒'),
            _buildStatRow('当前得分', '${stats['currentScore']}'),
            _buildStatRow('最高连胜', '${stats['bestStreak']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _gameService.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('清空记录'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

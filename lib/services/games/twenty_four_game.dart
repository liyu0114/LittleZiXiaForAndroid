/// 24点游戏
/// 
/// 经典数学游戏：用4张扑克牌（1-13），通过加减乘除运算得到24

import 'dart:math';
import 'package:flutter/foundation.dart';

/// 24点游戏状态
enum GameStatus {
  idle,       // 空闲
  playing,    // 游戏中
  solved,     // 已解决
  failed,     // 失败
  timeout,    // 超时
}

/// 游戏记录
class GameRecord {
  final List<int> numbers;
  final String? solution;
  final bool isSolved;
  final Duration timeSpent;
  final DateTime playedAt;

  GameRecord({
    required this.numbers,
    this.solution,
    required this.isSolved,
    required this.timeSpent,
    required this.playedAt,
  });
}

/// 24点游戏服务
class TwentyFourGameService extends ChangeNotifier {
  final Random _random = Random();
  
  // 游戏状态
  GameStatus _status = GameStatus.idle;
  List<int> _numbers = [];
  String? _solution;
  String? _userAnswer;
  bool _isCorrect = false;
  DateTime? _startTime;
  int _score = 0;
  int _streak = 0;
  
  // 历史记录
  final List<GameRecord> _history = [];
  
  // Getters
  GameStatus get status => _status;
  List<int> get numbers => List.unmodifiable(_numbers);
  String? get solution => _solution;
  String? get userAnswer => _userAnswer;
  bool get isCorrect => _isCorrect;
  int get score => _score;
  int get streak => _streak;
  List<GameRecord> get history => List.unmodifiable(_history);
  Duration get timeSpent => _startTime != null 
      ? DateTime.now().difference(_startTime!) 
      : Duration.zero;
  
  /// 开始新游戏
  void startNewGame() {
    _numbers = _generateNumbers();
    _solution = _findSolution(_numbers);
    _status = GameStatus.playing;
    _userAnswer = null;
    _isCorrect = false;
    _startTime = DateTime.now();
    
    debugPrint('[24Game] 新游戏: $_numbers');
    debugPrint('[24Game] 答案: $_solution');
    
    notifyListeners();
  }
  
  /// 生成4个数字（确保有解）
  List<int> _generateNumbers() {
    // 尝试生成有解的题目
    for (int i = 0; i < 100; i++) {
      final numbers = [
        _random.nextInt(13) + 1,  // 1-13
        _random.nextInt(13) + 1,
        _random.nextInt(13) + 1,
        _random.nextInt(13) + 1,
      ];
      
      if (_findSolution(numbers) != null) {
        return numbers;
      }
    }
    
    // 如果100次都没找到，用经典题目
    return [8, 3, 8, 3];  // (8/(3-8/3)) = 24
  }
  
  /// 提交答案
  bool submitAnswer(String answer) {
    if (_status != GameStatus.playing) return false;
    
    _userAnswer = answer.trim();
    
    // 验证答案
    _isCorrect = _verifyAnswer(_userAnswer!, _numbers);
    
    if (_isCorrect) {
      _status = GameStatus.solved;
      _score += 10 + _streak * 2;  // 连胜加分
      _streak++;
      
      // 保存记录
      _history.add(GameRecord(
        numbers: _numbers,
        solution: _userAnswer,
        isSolved: true,
        timeSpent: timeSpent,
        playedAt: DateTime.now(),
      ));
      
      debugPrint('[24Game] 正确! 得分: $_score, 连胜: $_streak');
    } else {
      _streak = 0;  // 连胜中断
      debugPrint('[24Game] 错误!');
    }
    
    notifyListeners();
    return _isCorrect;
  }
  
  /// 放弃（查看答案）
  void giveUp() {
    if (_status != GameStatus.playing) return;
    
    _status = GameStatus.failed;
    _streak = 0;
    _userAnswer = _solution;
    
    // 保存记录
    _history.add(GameRecord(
      numbers: _numbers,
      solution: _solution,
      isSolved: false,
      timeSpent: timeSpent,
      playedAt: DateTime.now(),
    ));
    
    debugPrint('[24Game] 放弃');
    notifyListeners();
  }
  
  /// 跳过（无解题目）
  void skip() {
    if (_status != GameStatus.playing) return;
    
    _status = GameStatus.failed;
    _streak = 0;
    
    debugPrint('[24Game] 跳过');
    notifyListeners();
  }
  
  /// 重置游戏
  void reset() {
    _status = GameStatus.idle;
    _numbers = [];
    _solution = null;
    _userAnswer = null;
    _isCorrect = false;
    _startTime = null;
    notifyListeners();
  }
  
  /// 清空历史
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
  
  /// 查找答案（暴力搜索）
  String? _findSolution(List<int> numbers) {
    final ops = ['+', '-', '*', '/'];
    
    // 尝试所有排列组合
    for (final perm in _permutations(numbers)) {
      for (final op1 in ops) {
        for (final op2 in ops) {
          for (final op3 in ops) {
            // 尝试不同的括号组合
            final expressions = [
              // ((a op b) op c) op d
              '((${perm[0]}$op1${perm[1]})$op2${perm[2]})$op3${perm[3]}',
              // (a op (b op c)) op d
              '(${perm[0]}$op1(${perm[1]}$op2${perm[2]}))$op3${perm[3]}',
              // (a op b) op (c op d)
              '(${perm[0]}$op1${perm[1]})$op2(${perm[2]}$op3${perm[3]})',
              // a op ((b op c) op d)
              '${perm[0]}$op1((${perm[1]}$op2${perm[2]})$op3${perm[3]})',
              // a op (b op (c op d))
              '${perm[0]}$op1(${perm[1]}$op2(${perm[2]}$op3${perm[3]}))',
            ];
            
            for (final expr in expressions) {
              try {
                final result = _evaluate(expr);
                if ((result - 24).abs() < 0.0001) {
                  return expr;
                }
              } catch (e) {
                // 忽略无效表达式
              }
            }
          }
        }
      }
    }
    
    return null;
  }
  
  /// 生成所有排列
  List<List<int>> _permutations(List<int> list) {
    if (list.length <= 1) return [list];
    
    final result = <List<int>>[];
    for (int i = 0; i < list.length; i++) {
      final current = list[i];
      final remaining = [...list.sublist(0, i), ...list.sublist(i + 1)];
      for (final perm in _permutations(remaining)) {
        result.add([current, ...perm]);
      }
    }
    return result;
  }
  
  /// 计算表达式
  double _evaluate(String expr) {
    // 简单的表达式求值（实际项目中应该用更安全的方式）
    // 这里用递归下降解析
    
    int pos = 0;
    
    double parseExpression() {
      double left = parseTerm();
      
      while (pos < expr.length && (expr[pos] == '+' || expr[pos] == '-')) {
        final op = expr[pos];
        pos++;
        final right = parseTerm();
        left = op == '+' ? left + right : left - right;
      }
      
      return left;
    }
    
    double parseTerm() {
      double left = parseFactor();
      
      while (pos < expr.length && (expr[pos] == '*' || expr[pos] == '/')) {
        final op = expr[pos];
        pos++;
        final right = parseFactor();
        left = op == '*' ? left * right : left / right;
      }
      
      return left;
    }
    
    double parseFactor() {
      // 跳过空格
      while (pos < expr.length && expr[pos] == ' ') pos++;
      
      // 处理括号
      if (expr[pos] == '(') {
        pos++;  // 跳过 '('
        final result = parseExpression();
        pos++;  // 跳过 ')'
        return result;
      }
      
      // 处理数字
      final start = pos;
      while (pos < expr.length && (expr[pos].codeUnitAt(0) >= 48 && expr[pos].codeUnitAt(0) <= 57 || expr[pos] == '.')) {
        pos++;
      }
      
      return double.parse(expr.substring(start, pos));
    }
    
    return parseExpression();
  }
  
  /// 验证用户答案
  bool _verifyAnswer(String answer, List<int> numbers) {
    // 1. 提取答案中的数字
    final numRegex = RegExp(r'\d+');
    final matches = numRegex.allMatches(answer);
    final answerNumbers = matches.map((m) => int.parse(m.group(0)!)).toList();
    
    // 2. 检查数字是否匹配（顺序可以不同）
    if (answerNumbers.length != 4) return false;
    
    final sortedAnswer = List.from(answerNumbers)..sort();
    final sortedNumbers = List.from(numbers)..sort();
    
    for (int i = 0; i < 4; i++) {
      if (sortedAnswer[i] != sortedNumbers[i]) return false;
    }
    
    // 3. 检查是否使用了非法字符（只允许数字、运算符、括号、空格）
    final validChars = RegExp(r'^[\d+\-*/().\s]+$');
    if (!validChars.hasMatch(answer)) return false;
    
    // 4. 计算结果是否等于24
    try {
      final result = _evaluate(answer);
      return (result - 24).abs() < 0.0001;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取提示（显示一个数字的位置）
  String getHint() {
    if (_solution == null || _numbers.isEmpty) return '';
    
    // 返回答案的第一个数字和运算符
    final hint = _solution!.substring(0, _solution!.length > 10 ? 10 : _solution!.length);
    return '提示: $hint...';
  }
  
  /// 获取统计信息
  Map<String, dynamic> get statistics {
    final solved = _history.where((r) => r.isSolved).length;
    final total = _history.length;
    final avgTime = total > 0
        ? _history.map((r) => r.timeSpent.inSeconds).reduce((a, b) => a + b) / total
        : 0.0;
    
    return {
      'totalGames': total,
      'solved': solved,
      'failed': total - solved,
      'successRate': total > 0 ? solved / total : 0,
      'averageTime': avgTime,
      'currentScore': _score,
      'currentStreak': _streak,
      'bestStreak': _history.isNotEmpty 
          ? _calculateBestStreak() 
          : 0,
    };
  }
  
  int _calculateBestStreak() {
    int bestStreak = 0;
    int currentStreak = 0;
    
    for (final record in _history) {
      if (record.isSolved) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }
    }
    
    return bestStreak;
  }
}

// 自主学习服务
//
// 从交互中学习

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 学习样本
class LearningSample {
  final String input;
  final String output;
  final double reward;
  final DateTime timestamp;
  
  LearningSample({
    required this.input,
    required this.output,
    required this.reward,
    required this.timestamp,
  });
}

/// 学习策略
enum LearningStrategy {
  reinforcement,  // 强化学习
  imitation,       // 模仿学习
  exploration,    // 探索学习
}

/// 自主学习器
class AutonomousLearner extends ChangeNotifier {
  final List<LearningSample> _samples = [];
  final Map<String, int> _qTable = {};
  
  static const int MAX_SAMPLES = 500;
  static const double LEARNING_RATE = 0.1;
  static const double DISCOUNT = 0.9;
  
  /// 添加样本
  void addSample(String input, String output, double reward) {
    _samples.add(LearningSample(
      input: input,
      output: output,
      reward: reward,
      timestamp: DateTime.now(),
    ));
    
    // 更新Q表
    _updateQTable(input, output, reward);
    
    // 清理旧样本
    if (_samples.length > MAX_SAMPLES) {
      _samples.removeAt(0);
    }
    
    notifyListeners();
  }
  
  void _updateQTable(String input, String output, double reward) {
    final key = '$input->$output';
    final oldValue = _qTable[key] ?? 0;
    _qTable[key] = ((1 - LEARNING_RATE) * oldValue + LEARNING_RATE * reward).round();
  }
  
  /// 学习策略
  void setStrategy(LearningStrategy strategy) {
    // TODO: 根据策略调整学习
    debugPrint('[AutonomousLearner] 策略: $strategy');
    notifyListeners();
  }
  
  /// 推理
  String? infer(String input) {
    // 找最佳输出
    String? bestOutput;
    int bestScore = -999;
    
    for (final entry in _qTable.entries) {
      if (entry.key.startsWith('$input->')) {
        if (entry.value > bestScore) {
          bestScore = entry.value;
          bestOutput = entry.key.split('->')[1];
        }
      }
    }
    
    return bestOutput;
  }
  
  /// 探索新策略
  String? explore(String input, List<String> candidates) {
    // ε-greedy探索
    if (DateTime.now().millisecond % 10 == 0) {
      return candidates[DateTime.now().second % candidates.length];
    }
    return infer(input);
  }
  
  /// 获取学习统计
  Map<String, int> getStats() {
    return {
      'samples': _samples.length,
      'q_entries': _qTable.length,
    };
  }
  
  /// 清空学习
  void reset() {
    _samples.clear();
    _qTable.clear();
    notifyListeners();
  }
}
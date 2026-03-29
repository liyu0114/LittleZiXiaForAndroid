// Group Chat 智能行为
//
// 决定何时参与群聊

import 'package:flutter/foundation.dart';

/// Group Chat 策略
enum GroupChatStrategy {
  always,      // 总是回复
  smart,       // 智能回复（默认）
  minimal,     // 最小化回复
  silent,      // 静默
}

/// Group Chat 服务
class GroupChatService extends ChangeNotifier {
  GroupChatStrategy _strategy = GroupChatStrategy.smart;
  int _replyCount = 0;
  DateTime? _lastReplyTime;

  GroupChatStrategy get strategy => _strategy;
  int get replyCount => _replyCount;
  DateTime? get lastReplyTime => _lastReplyTime;

  /// 设置策略
  void setStrategy(GroupChatStrategy strategy) {
    _strategy = strategy;
    notifyListeners();
  }

  /// 决定是否应该回复
  bool shouldReply({
    required String message,
    required bool isDirectlyMentioned,
    required bool isQuestion,
    required bool hasValue,
    required bool someoneAnswered,
  }) {
    switch (_strategy) {
      case GroupChatStrategy.always:
        return true;

      case GroupChatStrategy.silent:
        return false;

      case GroupChatStrategy.minimal:
        // 只在直接提及时回复
        return isDirectlyMentioned || isQuestion;

      case GroupChatStrategy.smart:
        return _smartReply(
          message: message,
          isDirectlyMentioned: isDirectlyMentioned,
          isQuestion: isQuestion,
          hasValue: hasValue,
          someoneAnswered: someoneAnswered,
        );
    }
  }

  /// 智能回复策略
  bool _smartReply({
    required String message,
    required bool isDirectlyMentioned,
    required bool isQuestion,
    required bool hasValue,
    required bool someoneAnswered,
  }) {
    // 直接提及：总是回复
    if (isDirectlyMentioned) return true;

    // 问题且没人回答：回复
    if (isQuestion && !someoneAnswered) return true;

    // 有价值的信息：回复
    if (hasValue) return true;

    // 纠正重要错误：回复
    // TODO: 检测错误信息

    // 其他情况：不回复
    return false;
  }

  /// 记录回复
  void recordReply() {
    _replyCount++;
    _lastReplyTime = DateTime.now();
    notifyListeners();
  }

  /// 检测是否是问题
  static bool isQuestion(String message) {
    final questionMarks = ['?', '？'];
    final questionWords = ['吗', '呢', '怎么', '什么', '为什么', '如何', '哪'];

    // 检查问号
    if (questionMarks.any((mark) => message.contains(mark))) {
      return true;
    }

    // 检查疑问词
    if (questionWords.any((word) => message.contains(word))) {
      return true;
    }

    return false;
  }

  /// 检测是否有价值
  static bool hasValue(String message) {
    final valueIndicators = [
      '建议', '提示', '技巧', '方法', '方案',
      '推荐', '评价', '分析', '总结',
    ];

    return valueIndicators.any((indicator) => message.contains(indicator));
  }

  /// 检测是否是直接提及
  static bool isDirectlyMentioned(String message, List<String> names) {
    final lowerMessage = message.toLowerCase();
    return names.any((name) => lowerMessage.contains(name.toLowerCase()));
  }
}

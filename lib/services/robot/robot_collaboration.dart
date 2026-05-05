// 机器人协作服务
//
// 多机器人讨论+决策

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 机器人角色
enum RobotRole {
  leader,     // 主导者：发起讨论、做决定
  member,     // 成员：参与讨论、接受委派
  observer,   // 观察者：只听不说
}

/// 机器人
class Robot {
  final String id;
  final String name;
  final RobotRole role;
  bool isActive;
  
  Robot({
    required this.id,
    required this.name,
    required this.role,
    this.isActive = true,
  });
}

/// 讨论消息
class DiscussionMessage {
  final String id;
  final String robotId;
  final String content;
  final DateTime timestamp;
  final bool isDecision;
  
  DiscussionMessage({
    required this.id,
    required this.robotId,
    required this.content,
    required this.timestamp,
    this.isDecision = false,
  });
}

/// 讨论
class Discussion {
  final String id;
  final String topic;
  final List<Robot> participants;
  final List<DiscussionMessage> messages;
  final Robot? leader;
  bool isConcluded;
  String? conclusion;
  
  Discussion({
    required this.id,
    required this.topic,
    required this.participants,
    required this.messages,
    this.leader,
    this.isConcluded = false,
    this.conclusion,
  });
}

/// 机器人协作管理器
class RobotCollaboration extends ChangeNotifier {
  final List<Discussion> _discussions = [];
  
  /// 发起讨论
  Future<Discussion> startDiscussion(String topic, List<Robot> robots) async {
    // 确保有leader
    final leader = robots.firstWhere(
      (r) => r.role == RobotRole.leader,
      orElse: () => robots.first,
    );
    
    final discussion = Discussion(
      id: 'disc_${DateTime.now().millisecondsSinceEpoch}',
      topic: topic,
      participants: robots,
      messages: [],
      leader: leader,
    );
    
    _discussions.add(discussion);
    notifyListeners();
    
    return discussion;
  }
  
  /// 机器人发言
  Future<void> speak(String discussionId, String robotId, String content) async {
    final disc = _discussions.firstWhere((d) => d.id == discussionId);
    final robot = disc.participants.firstWhere((r) => r.id == robotId);
    
    // observer不能发言
    if (robot.role == RobotRole.observer) return;
    
    disc.messages.add(DiscussionMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      robotId: robotId,
      content: content,
      timestamp: DateTime.now(),
    ));
    
    notifyListeners();
  }
  
  /// leader做决定
  Future<void> decide(String discussionId, String content) async {
    final disc = _discussions.firstWhere((d) => d.id == discussionId);
    
    disc.messages.add(DiscussionMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      robotId: disc.leader!.id,
      content: content,
      timestamp: DateTime.now(),
      isDecision: true,
    ));
    
    disc.isConcluded = true;
    disc.conclusion = content;
    
    notifyListeners();
  }
  
  /// 终止讨论（人类权限）
  void conclude(String discussionId, String? conclusion) async {
    final disc = _discussions.firstWhere((d) => d.id == discussionId);
    
    disc.isConcluded = true;
    disc.conclusion = conclusion ?? '人类终止讨论';
    
    notifyListeners();
  }
  
  /// 获取讨论历史
  List<DiscussionMessage> getHistory(String discussionId) {
    final disc = _discussions.firstWhere((d) => d.id == discussionId);
    return disc.messages;
  }
  
  /// 获取活跃讨论
  List<Discussion> getActiveDiscussions() {
    return _discussions.where((d) => !d.isConcluded).toList();
  }
}
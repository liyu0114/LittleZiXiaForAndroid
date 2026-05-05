// 机器人标识服务
//
// @提及+头像+名字定制

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 机器人标识
class RobotIdentity {
  final String id;
  final String name;
  final String? nickname;
  final String? avatar;
  final String? description;
  final List<String> keywords;
  final bool isActive;
  
  RobotIdentity({
    required this.id,
    required this.name,
    this.nickname,
    this.avatar,
    this.description,
    this.keywords = const [],
    this.isActive = true,
  });
}

/// 机器人标识管理器
class RobotIdentityManager extends ChangeNotifier {
  final List<RobotIdentity> _identities = [];
  
  /// 添加机器人
  void addRobot(String name, {String? nickname, String? avatar}) {
    _identities.add(RobotIdentity(
      id: 'robot_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      nickname: nickname,
      avatar: avatar,
    ));
    notifyListeners();
  }
  
  /// @提及解析
  List<RobotIdentity> parseMention(String text) {
    final results = <RobotIdentity>[];
    
    for (final robot in _identities) {
      // 检查@名称
      if (text.contains('@${robot.name}')) {
        results.add(robot);
      }
      // 检查@昵称
      if (robot.nickname != null && text.contains('@${robot.nickname}')) {
        results.add(robot);
      }
    }
    
    return results;
  }
  
  /// 获取机器人
  RobotIdentity? getRobot(String id) {
    return _identities.firstOrNull;
  }
  
  /// 设置头像
  void setAvatar(String id, String avatar) {
    final index = _identities.indexWhere((r) => r.id == id);
    if (index != -1) {
      _identities[index] = RobotIdentity(
        id: _identities[index].id,
        name: _identities[index].name,
        nickname: _identities[index].nickname,
        avatar: avatar,
        description: _identities[index].description,
        keywords: _identities[index].keywords,
        isActive: _identities[index].isActive,
      );
      notifyListeners();
    }
  }
  
  /// 设置昵称
  void setNickname(String id, String nickname) {
    final index = _identities.indexWhere((r) => r.id == id);
    if (index != -1) {
      _identities[index] = RobotIdentity(
        id: _identities[index].id,
        name: _identities[index].name,
        nickname: nickname,
        avatar: _identities[index].avatar,
        description: _identities[index].description,
        keywords: _identities[index].keywords,
        isActive: _identities[index].isActive,
      );
      notifyListeners();
    }
  }
  
  /// 关键词触发
  void addKeyword(String id, String keyword) {
    final index = _identities.indexWhere((r) => r.id == id);
    if (index != -1) {
      final robot = _identities[index];
      final keywords = List<String>.from(robot.keywords)..add(keyword);
      
      _identities[index] = RobotIdentity(
        id: robot.id,
        name: robot.name,
        nickname: robot.nickname,
        avatar: robot.avatar,
        description: robot.description,
        keywords: keywords,
        isActive: robot.isActive,
      );
      notifyListeners();
    }
  }
  
  /// 获取所有机器人
  List<RobotIdentity> getAll() => List.unmodifiable(_identities);
  
  /// 移除机器人
  void removeRobot(String id) {
    _identities.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
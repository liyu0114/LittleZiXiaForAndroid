// 24点游戏记分服务
//
// 记录玩家成绩、胜利次数、历史答案

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 玩家游戏记录
class PlayerGameRecord {
  final String playerId;
  final String playerName;
  int totalGames;      // 总游戏数
  int wins;            // 胜利次数
  int losses;          // 失败次数
  int fastestWin;      // 最快获胜时间（秒）
  List<String> historyAnswers;  // 历史答案
  DateTime lastPlayed; // 最后游戏时间
  
  PlayerGameRecord({
    required this.playerId,
    required this.playerName,
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.fastestWin = 0,
    List<String>? historyAnswers,
    DateTime? lastPlayed,
  }) : historyAnswers = historyAnswers ?? [],
       lastPlayed = lastPlayed ?? DateTime.now();
  
  /// 胜率
  double get winRate => totalGames > 0 ? wins / totalGames : 0;
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'totalGames': totalGames,
    'wins': wins,
    'losses': losses,
    'fastestWin': fastestWin,
    'historyAnswers': historyAnswers,
    'lastPlayed': lastPlayed.toIso8601String(),
  };
  
  /// 从 JSON 创建
  factory PlayerGameRecord.fromJson(Map<String, dynamic> json) {
    return PlayerGameRecord(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      totalGames: json['totalGames'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      fastestWin: json['fastestWin'] as int? ?? 0,
      historyAnswers: List<String>.from(json['historyAnswers'] as List? ?? []),
      lastPlayed: DateTime.parse(json['lastPlayed'] as String),
    );
  }
  
  /// 复制并更新
  PlayerGameRecord copyWith({
    int? totalGames,
    int? wins,
    int? losses,
    int? fastestWin,
    List<String>? historyAnswers,
    DateTime? lastPlayed,
  }) {
    return PlayerGameRecord(
      playerId: playerId,
      playerName: playerName,
      totalGames: totalGames ?? this.totalGames,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      fastestWin: fastestWin ?? this.fastestWin,
      historyAnswers: historyAnswers ?? this.historyAnswers,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}

/// 24点游戏记分服务
class TwentyFourScoreService extends ChangeNotifier {
  static const String _storageKey = 'twenty_four_scores';
  
  // 玩家记录
  final Map<String, PlayerGameRecord> _records = {};
  
  // 是否已初始化
  bool _initialized = false;
  
  /// 获取玩家记录
  PlayerGameRecord? getRecord(String playerId) {
    return _records[playerId];
  }
  
  /// 获取所有记录
  List<PlayerGameRecord> getAllRecords() {
    final list = _records.values.toList();
    list.sort((a, b) => b.wins.compareTo(a.wins));  // 按胜利次数排序
    return list;
  }
  
  /// 获取排行榜
  List<PlayerGameRecord> getLeaderboard({int limit = 10}) {
    return getAllRecords().take(limit).toList();
  }
  
  /// 初始化（从本地存储加载）
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      
      if (data != null) {
        final json = jsonDecode(data) as List;
        for (final item in json) {
          final record = PlayerGameRecord.fromJson(item as Map<String, dynamic>);
          _records[record.playerId] = record;
        }
      }
      
      _initialized = true;
      debugPrint('[TwentyFourScore] 已加载 ${_records.length} 条记录');
    } catch (e) {
      debugPrint('[TwentyFourScore] 加载失败: $e');
    }
  }
  
  /// 保存到本地存储
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _records.values.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[TwentyFourScore] 保存失败: $e');
    }
  }
  
  /// 记录游戏结果
  Future<void> recordGame({
    required String playerId,
    required String playerName,
    required bool isWin,
    int? winTime,
    String? answer,
  }) async {
    var record = _records[playerId];
    
    if (record == null) {
      // 创建新记录
      record = PlayerGameRecord(
        playerId: playerId,
        playerName: playerName,
      );
    }
    
    // 更新记录
    final newRecord = record.copyWith(
      totalGames: record.totalGames + 1,
      wins: isWin ? record.wins + 1 : record.wins,
      losses: !isWin ? record.losses + 1 : record.losses,
      fastestWin: (isWin && winTime != null && (record.fastestWin == 0 || winTime < record.fastestWin))
          ? winTime 
          : record.fastestWin,
      lastPlayed: DateTime.now(),
    );
    
    // 添加历史答案
    if (answer != null && answer.isNotEmpty) {
      final newHistory = List<String>.from(newRecord.historyAnswers);
      newHistory.add(answer);
      // 只保留最近 20 条
      if (newHistory.length > 20) {
        newHistory.removeAt(0);
      }
      _records[playerId] = newRecord.copyWith(historyAnswers: newHistory);
    } else {
      _records[playerId] = newRecord;
    }
    
    notifyListeners();
    await _save();
    
    debugPrint('[TwentyFourScore] 记录游戏: $playerName, 胜利: $isWin, 总胜利: ${_records[playerId]!.wins}');
  }
  
  /// 获取玩家统计信息
  String getPlayerStats(String playerId) {
    final record = _records[playerId];
    if (record == null) {
      return '暂无记录';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('📊 ${record.playerName} 的战绩');
    buffer.writeln('');
    buffer.writeln('🎮 总游戏: ${record.totalGames} 局');
    buffer.writeln('🏆 胜利: ${record.wins} 局');
    buffer.writeln('💔 失败: ${record.losses} 局');
    buffer.writeln('📈 胜率: ${(record.winRate * 100).toStringAsFixed(1)}%');
    
    if (record.fastestWin > 0) {
      buffer.writeln('⚡ 最快获胜: ${record.fastestWin} 秒');
    }
    
    return buffer.toString().trim();
  }
  
  /// 获取排行榜文本
  String getLeaderboardText({int limit = 5}) {
    final leaderboard = getLeaderboard(limit: limit);
    
    if (leaderboard.isEmpty) {
      return '暂无排行榜数据';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('🏆 24点排行榜');
    buffer.writeln('');
    
    final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
    
    for (var i = 0; i < leaderboard.length; i++) {
      final record = leaderboard[i];
      final medal = i < medals.length ? medals[i] : '${i + 1}.';
      buffer.writeln('$medal ${record.playerName}: ${record.wins} 胜');
    }
    
    return buffer.toString().trim();
  }
  
  /// 清空所有记录
  Future<void> clearAll() async {
    _records.clear();
    notifyListeners();
    await _save();
  }
}

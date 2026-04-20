// 任务状态持久化服务
//
// 通用机制：保存每个任务的执行状态（进度、中间结果、对话历史）
// 目的：任务失败或超时后，用户可以"继续"而不是从头开始

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 任务快照 — 保存某一时刻的完整执行状态
class TaskSnapshot {
  final String taskId;
  final String originalTask;         // 用户原始请求
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;                // running / completed / failed / cancelled
  final List<Map<String, dynamic>> messages;  // 完整的对话历史（序列化后的 ChatMessage）
  final int iteration;
  final int maxIterations;
  final Map<String, String> toolResults;      // 工具名 -> 最新结果摘要
  final String? error;
  final String? partialResult;       // 已收集的部分结果

  TaskSnapshot({
    required this.taskId,
    required this.originalTask,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.messages,
    required this.iteration,
    required this.maxIterations,
    required this.toolResults,
    this.error,
    this.partialResult,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'originalTask': originalTask,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    'messages': messages,
    'iteration': iteration,
    'maxIterations': maxIterations,
    'toolResults': toolResults,
    'error': error,
    'partialResult': partialResult,
  };

  factory TaskSnapshot.fromJson(Map<String, dynamic> json) => TaskSnapshot(
    taskId: json['taskId'] ?? '',
    originalTask: json['originalTask'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    status: json['status'] ?? 'unknown',
    messages: List<Map<String, dynamic>>.from(json['messages'] ?? []),
    iteration: json['iteration'] ?? 0,
    maxIterations: json['maxIterations'] ?? 15,
    toolResults: Map<String, String>.from(json['toolResults'] ?? {}),
    error: json['error'],
    partialResult: json['partialResult'],
  );

  /// 是否可以被恢复
  bool get canResume => status == 'failed' || status == 'cancelled';
}

/// 任务状态服务 — 单例
class TaskStateService {
  static final TaskStateService _instance = TaskStateService._internal();
  factory TaskStateService() => _instance;
  TaskStateService._internal();

  static const String _storageKey = 'task_snapshots';
  static const int _maxSnapshots = 10;  // 最多保留10个任务快照

  /// 保存任务快照
  Future<void> saveSnapshot(TaskSnapshot snapshot) async {
    try {
      final snapshots = await _loadAll();
      
      // 更新或新增
      final idx = snapshots.indexWhere((s) => s.taskId == snapshot.taskId);
      if (idx >= 0) {
        snapshots[idx] = snapshot;
      } else {
        snapshots.add(snapshot);
      }

      // 只保留最近的 _maxSnapshots 个
      while (snapshots.length > _maxSnapshots) {
        snapshots.removeAt(0);
      }

      await _saveAll(snapshots);
      debugPrint('[TaskState] 保存快照: ${snapshot.taskId} (${snapshot.status})');
    } catch (e) {
      debugPrint('[TaskState] 保存快照失败: $e');
    }
  }

  /// 获取最近一个可恢复的任务
  Future<TaskSnapshot?> getLatestResumable() async {
    final snapshots = await _loadAll();
    final resumable = snapshots.where((s) => s.canResume).toList();
    if (resumable.isEmpty) return null;
    
    // 返回最近更新的
    resumable.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return resumable.first;
  }

  /// 根据 taskId 获取快照
  Future<TaskSnapshot?> getSnapshot(String taskId) async {
    final snapshots = await _loadAll();
    try {
      return snapshots.firstWhere((s) => s.taskId == taskId);
    } catch (_) {
      return null;
    }
  }

  /// 搜索与某描述匹配的最近任务
  Future<TaskSnapshot?> findRelatedTask(String taskDescription) async {
    final snapshots = await _loadAll();
    final keywords = _extractKeywords(taskDescription);
    
    TaskSnapshot? bestMatch;
    int bestScore = 0;

    for (final s in snapshots) {
      if (!s.canResume) continue;
      final taskKeywords = _extractKeywords(s.originalTask);
      int score = 0;
      for (final kw in keywords) {
        if (taskKeywords.contains(kw)) score++;
      }
      // 加权：更近的任务得分更高
      final ageHours = DateTime.now().difference(s.updatedAt).inHours;
      score = score * 10 - ageHours.clamp(0, 100);
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = s;
      }
    }

    // 至少要有一定匹配度
    if (bestScore > 0) return bestMatch;
    return null;
  }

  /// 标记任务已完成
  Future<void> markCompleted(String taskId, String result) async {
    final snapshot = await getSnapshot(taskId);
    if (snapshot == null) return;
    
    await saveSnapshot(TaskSnapshot(
      taskId: snapshot.taskId,
      originalTask: snapshot.originalTask,
      createdAt: snapshot.createdAt,
      updatedAt: DateTime.now(),
      status: 'completed',
      messages: snapshot.messages,
      iteration: snapshot.iteration,
      maxIterations: snapshot.maxIterations,
      toolResults: snapshot.toolResults,
      partialResult: result,
    ));
  }

  /// 清理过期快照（超过24小时的已完成任务）
  Future<void> cleanup() async {
    final snapshots = await _loadAll();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    
    final remaining = snapshots.where((s) {
      if (s.status == 'completed' || s.status == 'cancelled') {
        return s.updatedAt.isAfter(cutoff);
      }
      return true; // 保留失败/运行中的任务
    }).toList();

    if (remaining.length != snapshots.length) {
      await _saveAll(remaining);
      debugPrint('[TaskState] 清理: ${snapshots.length - remaining.length} 个过期快照');
    }
  }

  // ==================== 私有方法 ====================

  Future<List<TaskSnapshot>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json == null) return [];
      
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => TaskSnapshot.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[TaskState] 加载快照失败: $e');
      return [];
    }
  }

  Future<void> _saveAll(List<TaskSnapshot> snapshots) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(snapshots.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  /// 从任务描述中提取关键词
  List<String> _extractKeywords(String text) {
    final stopWords = {'的', '了', '在', '是', '我', '你', '他', '她', '它', '们',
        '这', '那', '有', '和', '与', '或', '不', '没', '要', '会', '能',
        'the', 'a', 'an', 'is', 'are', 'was', 'were', 'i', 'you', 'me',
        'my', 'your', 'it', 'this', 'that', 'and', 'or', 'but', 'to', 'for'};
    
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toList();
  }
}

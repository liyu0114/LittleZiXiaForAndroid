// 记忆系统服务
//
// 长期记忆+遗忘机制

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 记忆类型
enum MemoryType {
  semantic,   // 语义记忆（事实）
  episodic,   //情景记忆（事件）
  procedural, // 程序记忆（技能）
  transient,  // 临时记忆
}

/// 记忆
class Memory {
  final String id;
  final MemoryType type;
  final String content;
  final double importance; // 0-1
  final DateTime createdAt;
  DateTime lastAccessed;
  int accessCount;
  
  Memory({
    required this.id,
    required this.type,
    required this.content,
    required this.importance,
    required this.createdAt,
    required this.lastAccessed,
    this.accessCount = 0,
  });
}

/// 记忆管理器
class MemoryManager extends ChangeNotifier {
  final Map<String, Memory> _memories = {};
  static const int MAX_MEMORIES = 1000;
  static const double FORGET_THRESHOLD = 0.1;
  
  /// 添加记忆
  void memorize(String content, MemoryType type, {double importance = 0.5}) {
    final memory = Memory(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      content: content,
      importance: importance,
      createdAt: DateTime.now(),
      lastAccessed: DateTime.now(),
    );
    
    _memories[memory.id] = memory;
    
    // 检查容量
    if (_memories.length > MAX_MEMORIES) {
      _forget();
    }
    
    notifyListeners();
  }
  
  /// 回忆
  String? recall(String id) {
    final memory = _memories[id];
    if (memory != null) {
      memory.lastAccessed = DateTime.now();
      memory.accessCount++;
      notifyListeners();
      return memory.content;
    }
    return null;
  }
  
  /// 搜索记忆
  List<Memory> search(String query) {
    return _memories.values
        .where((m) => m.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  /// 遗忘低重要性记忆
  void _forget() {
    // 按重要性和访问频率遗忘
    final toForget = _memories.values.where((m) => 
      m.importance < FORGET_THRESHOLD && m.accessCount < 3
    ).toList();
    
    if (toForget.isNotEmpty) {
      final oldest = toForget.first;
      _memories.remove(oldest.id);
    }
  }
  
  /// 更新重要性
  void boostImportance(String id, double boost) {
    final memory = _memories[id];
    if (memory != null) {
      memory.importance = (memory.importance + boost).clamp(0.0, 1.0);
      notifyListeners();
    }
  }
  
  /// 获取记忆数量
  int get count => _memories.length;
  
  /// 清空临时记忆
  void clearTransient() {
    _memories.removeWhere((_, m) => m.type == MemoryType.transient);
    notifyListeners();
  }
}
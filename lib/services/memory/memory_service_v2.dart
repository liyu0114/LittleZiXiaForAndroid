// 记忆系统升级 - SQLite + FTS5
//
// 基于 OpenClaw memory 设计

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 记忆条目
class MemoryEntry {
  final int? id;
  final String content;
  final DateTime timestamp;
  final List<String> tags;
  final String? summary;
  final int importance; // 1-5 重要程度

  MemoryEntry({
    this.id,
    required this.content,
    required this.timestamp,
    this.tags = const [],
    this.summary,
    this.importance = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags.join(','),
      'summary': summary,
      'importance': importance,
    };
  }

  factory MemoryEntry.fromMap(Map<String, dynamic> map) {
    return MemoryEntry(
      id: map['id'] as int?,
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      tags: (map['tags'] as String?)?.split(',') ?? [],
      summary: map['summary'],
      importance: map['importance'] ?? 3,
    );
  }
}

/// 搜索结果
class MemorySearchResult {
  final MemoryEntry entry;
  final double score;
  final String highlight;

  MemorySearchResult({
    required this.entry,
    required this.score,
    required this.highlight,
  });
}

/// SQLite 记忆服务
class MemoryServiceV2 {
  static const String _dbName = 'memory.db';
  static const int _dbVersion = 1;
  
  Database? _db;
  bool _isReady = false;
  
  bool get isReady => _isReady;

  /// 初始化数据库
  Future<void> initialize() async {
    if (_isReady) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    
    _isReady = true;
    debugPrint('[MemoryV2] 初始化完成: $path');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 主表
    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tags TEXT,
        summary TEXT,
        importance INTEGER DEFAULT 3
      )
    ''');

    // FTS5 全文搜索表
    await db.execute('''
      CREATE VIRTUAL TABLE memories_fts USING fts5(
        content,
        tags,
        content='memories',
        content_rowid='id'
      )
    ''');

    // 索引元数据表
    await db.execute('''
      CREATE TABLE memory_index_meta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        last_indexed TEXT,
        total_entries INTEGER DEFAULT 0,
        total_size INTEGER DEFAULT 0
      )
    ''');

    debugPrint('[MemoryV2] 数据库表创建完成');
  }

  /// 添加记忆
  Future<int> add(MemoryEntry entry) async {
    if (_db == null) await initialize();
    
    final id = await _db!.insert('memories', entry.toMap());
    
    // 更新 FTS 索引
    await _db!.execute(
      "INSERT INTO memories_fts(rowid, content, tags) VALUES (?, ?, ?)",
      [id, entry.content, entry.tags.join(',')],
    );
    
    // 更新元数据
    await _updateMeta();
    
    debugPrint('[MemoryV2] 添加记忆: ID=$id');
    return id;
  }

  /// 搜索记忆（FTS5）
  Future<List<MemorySearchResult>> search(
    String query, {
    int limit = 5,
    double minScore = 0.0,
  }) async {
    if (_db == null) await initialize();
    
    final results = <MemorySearchResult>[];
    
    // FTS5 搜索
    final rows = await _db!.rawQuery('''
      SELECT m.*, bm.rank
      FROM memories_fts bm
      JOIN memories m ON bm.rowid = m.id
      WHERE memories_fts MATCH ?
      ORDER BY bm.rank
      LIMIT ?
    ''', [query, limit]);
    
    for (final row in rows) {
      final entry = MemoryEntry.fromMap(row);
      final score = 1.0 / (1.0 + (row['rank'] as num).toDouble());
      
      if (score >= minScore) {
        results.add(MemorySearchResult(
          entry: entry,
          score: score,
          highlight: _extractHighlight(entry.content, query),
        ));
      }
    }
    
    return results;
  }

  /// 关键词搜索（简单）
  Future<List<MemorySearchResult>> searchByKeyword(String keyword) async {
    if (_db == null) await initialize();
    
    final results = <MemorySearchResult>[];
    final rows = await _db!.query(
      'memories',
      where: 'content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'timestamp DESC',
      limit: 10,
    );
    
    for (final row in rows) {
      final entry = MemoryEntry.fromMap(row);
      results.add(MemorySearchResult(
        entry: entry,
        score: 1.0,
        highlight: _extractHighlight(entry.content, keyword),
      ));
    }
    
    return results;
  }

  /// 获取最近的记忆
  Future<List<MemoryEntry>> getRecent({int limit = 10}) async {
    if (_db == null) await initialize();
    
    final rows = await _db!.query(
      'memories',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return rows.map((r) => MemoryEntry.fromMap(r)).toList();
  }

  /// 删除记忆
  Future<void> delete(int id) async {
    if (_db == null) await initialize();
    
    await _db!.delete('memories', where: 'id = ?', whereArgs: [id]);
    await _db!.execute('DELETE FROM memories_fts WHERE rowid = ?', [id]);
  }

  /// 清空所有记忆
  Future<void> clear() async {
    if (_db == null) await initialize();
    
    await _db!.delete('memories');
    await _db!.execute('DELETE FROM memories_fts');
  }

  /// 统计
  Future<Map<String, dynamic>> stats() async {
    if (_db == null) await initialize();
    
    final count = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM memories'),
    ) ?? 0;
    
    final meta = await _db!.query('memory_index_meta', limit: 1);
    
    return {
      'total': count,
      'lastIndexed': meta.isNotEmpty ? meta.first['last_indexed'] : null,
    };
  }

  /// 更新索引元数据
  Future<void> _updateMeta() async {
    final count = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM memories'),
    ) ?? 0;
    
    await _db!.delete('memory_index_meta');
    await _db!.insert('memory_index_meta', {
      'last_indexed': DateTime.now().toIso8601String(),
      'total_entries': count,
    });
  }

  /// 提取高亮片段
  String _extractHighlight(String content, String query) {
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerContent.indexOf(lowerQuery);
    
    if (index < 0) return content.substring(0, content.length.clamp(0, 100));
    
    final start = (index - 20).clamp(0, content.length);
    final end = (index + query.length + 40).clamp(0, content.length);
    
    return '${start > 0 ? '...' : ''}${content.substring(start, end)}${end < content.length ? '...' : ''}';
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isReady = false;
  }
}
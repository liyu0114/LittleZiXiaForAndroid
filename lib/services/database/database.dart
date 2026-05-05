// 数据库管理服务
//
// 轻量级本地数据库

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 数据库记录
class DbRecord {
  String id;
  Map<String, dynamic> data;
  DateTime createdAt;
  DateTime updatedAt;
  
  DbRecord({
    required this.id,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 简单数据库
class Database extends ChangeNotifier {
  final Map<String, List<DbRecord>> _tables = {};
  
  /// 创建表
  void createTable(String name) {
    _tables[name] = [];
    notifyListeners();
  }
  
  /// 插入记录
  Future<void> insert(String table, Map<String, dynamic> data) async {
    _tables[table] ??= [];
    _tables[table]!.add(DbRecord(
      id: 'id_${DateTime.now().millisecondsSinceEpoch}',
      data: data,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    notifyListeners();
  }
  
  /// 查询
  List<DbRecord> query(String table, {String? where}) {
    final records = _tables[table] ?? [];
    if (where == null) return records;
    
    return records.where((r) => 
      r.data.values.any((v) => v.toString().contains(where))
    ).toList();
  }
  
  /// 更新
  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    final records = _tables[table] ?? [];
    final index = records.indexWhere((r) => r.id == id);
    if (index != -1) {
      records[index].data = data;
      records[index].updatedAt = DateTime.now();
      notifyListeners();
    }
  }
  
  /// 删除
  Future<void> delete(String table, String id) async {
    _tables[table]?.removeWhere((r) => r.id == id);
    notifyListeners();
  }
  
  /// 获取数量
  int count(String table) => _tables[table]?.length ?? 0;
}
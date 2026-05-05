// 数据库服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 数据库表
class Table {
  final String name;
  final List<Map<String, dynamic>> rows = [];
  
  Table(this.name);
  
  void insert(Map<String, dynamic> row) {
    rows.add({...row, 'id': rows.length + 1});
  }
  
  List<Map<String, dynamic>> selectAll() => rows;
  
  Map<String, dynamic>? selectById(int id) {
    return rows.where((r) => r['id'] == id).firstOrNull;
  }
  
  void update(int id, Map<String, dynamic> data) {
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index >= 0) {
      rows[index] = {...rows[index], ...data};
    }
  }
  
  void delete(int id) {
    rows.removeWhere((r) => r['id'] == id);
  }
  
  int get count => rows.length;
}

/// 简单数据库
class Database {
  final Map<String, Table> _tables = {};
  
  void createTable(String name) {
    _tables[name] = Table(name);
  }
  
  Table? getTable(String name) => _tables[name];
  
  bool hasTable(String name) => _tables.containsKey(name);
  
  void dropTable(String name) {
    _tables.remove(name);
  }
}

void main() {
  group('L1-12 数据库测试', () {
    
    test('测试1：创建表', () {
      final db = Database();
      db.createTable('users');
      expect(db.hasTable('users'), true);
    });
    
    test('测试2：插入数据', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': '张三', 'age': 25});
      
      expect(db.getTable('users')!.count, 1);
    });
    
    test('测试3：查询所有', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': '张三'});
      db.getTable('users')!.insert({'name': '李四'});
      
      final all = db.getTable('users')!.selectAll();
      expect(all.length, 2);
    });
    
    test('测试4：按ID查询', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': '张三'});
      db.getTable('users')!.insert({'name': '李四'});
      
      final user = db.getTable('users')!.selectById(2);
      expect(user?['name'], '李四');
    });
    
    test('测试5：更新数据', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': '张三', 'age': 25});
      
      db.getTable('users')!.update(1, {'age': 26});
      
      expect(db.getTable('users')!.selectById(1)?['age'], 26);
    });
    
    test('测试6：删除数据', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': '张三'});
      db.getTable('users')!.insert({'name': '李四'});
      
      db.getTable('users')!.delete(1);
      
      expect(db.getTable('users')!.count, 1);
    });
    
    test('测试7：删除表', () {
      final db = Database();
      db.createTable('users');
      db.dropTable('users');
      
      expect(db.hasTable('users'), false);
    });
    
    test('测试8：多表操作', () {
      final db = Database();
      db.createTable('users');
      db.createTable('posts');
      
      expect(db.hasTable('users'), true);
      expect(db.hasTable('posts'), true);
      expect(db.getTable('users')!.count, 0);
      expect(db.getTable('posts')!.count, 0);
    });
    
    test('测试9：自动ID生成', () {
      final db = Database();
      db.createTable('users');
      db.getTable('users')!.insert({'name': 'A'});
      db.getTable('users')!.insert({'name': 'B'});
      db.getTable('users')!.insert({'name': 'C'});
      
      expect(db.getTable('users')!.selectById(1)?['name'], 'A');
      expect(db.getTable('users')!.selectById(2)?['name'], 'B');
      expect(db.getTable('users')!.selectById(3)?['name'], 'C');
    });
    
    test('测试10：空表查询', () {
      final db = Database();
      db.createTable('users');
      
      final all = db.getTable('users')!.selectAll();
      expect(all.isEmpty, true);
    });
  });
}
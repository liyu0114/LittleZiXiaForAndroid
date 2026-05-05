// 记忆系统服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 记忆条目
class MemoryEntry {
  final String id;
  final String content;
  final String type;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  MemoryEntry({
    required this.id,
    required this.content,
    this.type = 'general',
    DateTime? createdAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 记忆服务
class MemoryService {
  final List<MemoryEntry> _entries = [];
  final int maxEntries;
  
  MemoryService({this.maxEntries = 100});
  
  List<MemoryEntry> get entries => _entries;
  
  void add(MemoryEntry entry) {
    _entries.add(entry);
    _trim();
  }
  
  void _trim() {
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }
  
  List<MemoryEntry> search(String query) {
    return _entries.where((e) => 
      e.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  void clear() => _entries.clear();
  
  int get count => _entries.length;
}

void main() {
  group('L1-13 记忆系统测试', () {
    
    test('测试1：添加记忆', () {
      final service = MemoryService();
      service.add(MemoryEntry(id: '1', content: '今天天气很好'));
      expect(service.count, 1);
    });
    
    test('测试2：搜索记忆', () {
      final service = MemoryService();
      service.add(MemoryEntry(id: '1', content: '今天天气很好'));
      service.add(MemoryEntry(id: '2', content: '明天下午有会'));
      
      final results = service.search('天气');
      expect(results.length, 1);
      expect(results.first.content, '今天天气很好');
    });
    
    test('测试3：不区分大小写搜索', () {
      final service = MemoryService();
      service.add(MemoryEntry(id: '1', content: 'HELLOWorld'));
      
      final results = service.search('helloworld');
      expect(results.length, 1);
    });
    
    test('测试4：自动清理超出条目', () {
      final service = MemoryService(maxEntries: 2);
      service.add(MemoryEntry(id: '1', content: '1'));
      service.add(MemoryEntry(id: '2', content: '2'));
      service.add(MemoryEntry(id: '3', content: '3'));
      
      expect(service.count, 2);
      expect(service.entries.first.id, '2');
    });
    
    test('测试5：清空记忆', () {
      final service = MemoryService();
      service.add(MemoryEntry(id: '1', content: 'test'));
      service.clear();
      
      expect(service.count, 0);
    });
    
    test('测试6：记忆类型', () {
      final entry = MemoryEntry(
        id: '1',
        content: '内容',
        type: 'conversation',
      );
      expect(entry.type, 'conversation');
    });
    
    test('测试7：记忆元数据', () {
      final entry = MemoryEntry(
        id: '1',
        content: '内容',
        metadata: {'source': 'user'},
      );
      expect(entry.metadata['source'], 'user');
    });
    
    test('测试8：多条搜索', () {
      final service = MemoryService();
      service.add(MemoryEntry(id: '1', content: '天气'));
      service.add(MemoryEntry(id: '2', content: '天气'));
      service.add(MemoryEntry(id: '3', content: '会议'));
      
      final results = service.search('天气');
      expect(results.length, 2);
    });
  });
}
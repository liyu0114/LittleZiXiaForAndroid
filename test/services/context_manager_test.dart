// 上下文管理服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 消息
class Message {
  final String id;
  final String content;
  final String role;
  final DateTime createdAt;
  
  Message({
    required this.id,
    required this.content,
    required this.role,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 上下文管理器
class ContextManager {
  final List<Message> _messages = [];
  final int maxTokens;
  final int maxMessages;
  
  ContextManager({
    this.maxTokens = 4000,
    this.maxMessages = 50,
  });
  
  List<Message> get messages => _messages;
  
  void addMessage(Message msg) {
    _messages.add(msg);
    _trim();
  }
  
  void _trim() {
    while (_messages.length > maxMessages) {
      _messages.removeAt(0);
    }
  }
  
  int get tokenCount {
    int count = 0;
    for (final msg in _messages) {
      count += msg.content.length ~/ 4;
    }
    return count;
  }
  
  bool get isFull => tokenCount >= maxTokens;
  
  List<Message> getRecentMessages(int count) {
    if (count >= _messages.length) return _messages;
    return _messages.sublist(_messages.length - count);
  }
  
  void clear() => _messages.clear();
  
  String get summary {
    if (_messages.isEmpty) return '';
    return '${_messages.length}条消息，共$tokenCount_tokens';
  }
  
  void compress() {
    if (_messages.length <= 2) return;
    
    final keep = _messages.sublist(_messages.length - 2);
    _messages.clear();
    _messages.addAll(keep);
  }
}

void main() {
  group('L1-04 超长上下文测试', () {
    
    test('测试1：添加消息', () {
      final manager = ContextManager();
      manager.addMessage(Message(id: '1', content: 'hello', role: 'user'));
      expect(manager.messages.length, 1);
    });
    
    test('测试2：Token计数', () {
      final manager = ContextManager(maxTokens: 1000);
      manager.addMessage(Message(id: '1', content: 'a' * 400, role: 'user'));
      expect(manager.tokenCount, 100);
    });
    
    test('测试3：满token检测', () {
      final manager = ContextManager(maxTokens: 100);
      manager.addMessage(Message(id: '1', content: 'a' * 400, role: 'user'));
      expect(manager.isFull, true);
    });
    
    test('测试4：获取最近消息', () {
      final manager = ContextManager();
      manager.addMessage(Message(id: '1', content: 'msg1', role: 'user'));
      manager.addMessage(Message(id: '2', content: 'msg2', role: 'assistant'));
      manager.addMessage(Message(id: '3', content: 'msg3', role: 'user'));
      
      final recent = manager.getRecentMessages(2);
      expect(recent.length, 2);
    });
    
    test('测试5：清空上下文', () {
      final manager = ContextManager();
      manager.addMessage(Message(id: '1', content: 'hello', role: 'user'));
      manager.clear();
      expect(manager.messages.isEmpty, true);
    });
    
    test('测试6：上下文摘要', () {
      final manager = ContextManager();
      manager.addMessage(Message(id: '1', content: 'hello', role: 'user'));
      manager.addMessage(Message(id: '2', content: 'hi', role: 'assistant'));
      
      expect(manager.summary, contains('2条消息'));
    });
    
    test('测试7：消息数量限制', () {
      final manager = ContextManager(maxMessages: 3);
      for (int i = 0; i < 5; i++) {
        manager.addMessage(Message(id: '$i', content: 'msg$i', role: 'user'));
      }
      expect(manager.messages.length, 3);
    });
    
    test('测试8：压缩保留最近', () {
      final manager = ContextManager();
      for (int i = 0; i < 5; i++) {
        manager.addMessage(Message(id: '$i', content: 'msg$i', role: 'user'));
      }
      
      manager.compress();
      expect(manager.messages.length, 2);
    });
    
    test('测试9：角色区分', () {
      final manager = ContextManager();
      manager.addMessage(Message(id: '1', content: 'hello', role: 'user'));
      manager.addMessage(Message(id: '2', content: 'hi', role: 'assistant'));
      
      expect(manager.messages[0].role, 'user');
      expect(manager.messages[1].role, 'assistant');
    });
    
    test('测试10：空上下文token', () {
      final manager = ContextManager();
      expect(manager.tokenCount, 0);
    });
  });
}
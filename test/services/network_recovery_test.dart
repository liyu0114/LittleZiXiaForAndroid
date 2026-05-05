// 网络恢复服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// 连接状态
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
}

/// 消息状态
enum MessageState {
  pending,
  sent,
  failed,
  acknowledged,
}

/// 网络消息
class NetworkMessage {
  final String id;
  final String content;
  MessageState state;
  final DateTime createdAt;
  int retryCount;
  
  NetworkMessage({
    required this.id,
    required this.content,
    this.state = MessageState.pending,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 网络恢复器
class NetworkRecovery {
  final List<NetworkMessage> _queue = [];
  final int maxRetries;
  final Duration retryInterval;
  
  NetworkRecovery({
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 5),
  });
  
  List<NetworkMessage> get queue => _queue;
  
  void addMessage(NetworkMessage msg) {
    _queue.add(msg);
  }
  
  void markSent(String id) {
    final msg = _queue.where((m) => m.id == id).firstOrNull;
    if (msg != null) {
      msg.state = MessageState.sent;
    }
  }
  
  void markFailed(String id) {
    final msg = _queue.where((m) => m.id == id).firstOrNull;
    if (msg != null) {
      msg.state = MessageState.failed;
      msg.retryCount++;
    }
  }
  
  void markAcknowledged(String id) {
    final msg = _queue.where((m) => m.id == id).firstOrNull;
    if (msg != null) {
      msg.state = MessageState.acknowledged;
    }
  }
  
  List<NetworkMessage> getPending() {
    return _queue.where((m) => m.state == MessageState.pending).toList();
  }
  
  List<NetworkMessage> getFailed() {
    return _queue.where((m) => 
      m.state == MessageState.failed && m.retryCount < maxRetries
    ).toList();
  }
  
  bool shouldRetry(String id) {
    final msg = _queue.where((m) => m.id == id).firstOrNull;
    if (msg == null) return false;
    return msg.state == MessageState.failed && msg.retryCount < maxRetries;
  }
  
  void removeAcknowledged() {
    _queue.removeWhere((m) => m.state == MessageState.acknowledged);
  }
  
  int get queueSize => _queue.length;
}

void main() {
  group('L1-05 断线重连测试', () {
    
    test('测试1：添加消息到队列', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      expect(recovery.queueSize, 1);
    });
    
    test('测试2：标记已发送', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      recovery.markSent('1');
      expect(recovery.queue.first.state, MessageState.sent);
    });
    
    test('测试3：标记失败并重试', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      recovery.markSent('1');
      recovery.markFailed('1');
      expect(recovery.queue.first.state, MessageState.failed);
      expect(recovery.queue.first.retryCount, 1);
    });
    
    test('测试4：标记确认', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      recovery.markSent('1');
      recovery.markAcknowledged('1');
      expect(recovery.queue.first.state, MessageState.acknowledged);
    });
    
    test('测试5：获取待发送列表', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      recovery.addMessage(NetworkMessage(id: '2', content: 'world'));
      recovery.markSent('1');
      
      final pending = recovery.getPending();
      expect(pending.length, 1);
      expect(pending.first.id, '2');
    });
    
    test('测试6：应该重试判断', () {
      final recovery = NetworkRecovery(maxRetries: 3);
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello', retryCount: 2));
      recovery.markFailed('1');
      
      expect(recovery.shouldRetry('1'), true);
      
      // 超过最大重试次数
      recovery.queue.first.retryCount = 3;
      expect(recovery.shouldRetry('1'), false);
    });
    
    test('测试7：清理已确认消息', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'hello'));
      recovery.addMessage(NetworkMessage(id: '2', content: 'world'));
      recovery.markAcknowledged('1');
      
      recovery.removeAcknowledged();
      expect(recovery.queueSize, 1);
    });
    
    test('测试8：获取可重试列表', () {
      final recovery = NetworkRecovery(maxRetries: 3);
      recovery.addMessage(NetworkMessage(id: '1', content: 'a', retryCount: 1));
      recovery.addMessage(NetworkMessage(id: '2', content: 'b', retryCount: 2));
      recovery.addMessage(NetworkMessage(id: '3', content: 'c', retryCount: 3));
      recovery.markFailed('1');
      recovery.markFailed('2');
      
      final failed = recovery.getFailed();
      expect(failed.length, 2);
    });
    
    test('测试9：重试次数限制', () {
      final recovery = NetworkRecovery(maxRetries: 2);
      final msg = NetworkMessage(id: '1', content: 'hello');
      
      recovery.addMessage(msg);
      recovery.markFailed('1');
      recovery.markFailed('1');
      recovery.markFailed('1');
      
      expect(recovery.shouldRetry('1'), false);
    });
    
    test('测试10：并发消息顺序', () {
      final recovery = NetworkRecovery();
      recovery.addMessage(NetworkMessage(id: '1', content: 'msg1'));
      recovery.addMessage(NetworkMessage(id: '2', content: 'msg2'));
      recovery.addMessage(NetworkMessage(id: '3', content: 'msg3'));
      
      expect(recovery.queueSize, 3);
      expect(recovery.getPending().length, 3);
    });
  });
}
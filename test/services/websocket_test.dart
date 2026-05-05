// WebSocket服务测试 - L1 单元测试
import 'package:flutter_test/flutter_test.dart';

/// WebSocket事件类型
enum WsEventType {
  connected,
  message,
  binary,
  error,
  closed,
}

/// WebSocket事件
class WsEvent {
  final WsEventType type;
  final String? data;
  
  WsEvent({required this.type, this.data});
}

/// WebSocket状态
enum WsState {
  disconnected,
  connecting,
  connected,
  closing,
}

/// WebSocket管理器
class WebSocketManager {
  final List<WsEvent> _events = [];
  WsState _state = WsState.disconnected;
  final String url;
  
  WebSocketManager(this.url);
  
  WsState get state => _state;
  List<WsEvent> get events => _events;
  
  Future<bool> connect() async {
    _state = WsState.connecting;
    await Future.delayed(Duration(milliseconds: 10));
    _state = WsState.connected;
    _events.add(WsEvent(type: WsEventType.connected));
    return true;
  }
  
  Future<void> disconnect() async {
    _state = WsState.closing;
    await Future.delayed(Duration(milliseconds: 10));
    _state = WsState.disconnected;
    _events.add(WsEvent(type: WsEventType.closed));
  }
  
  void send(String message) {
    if (_state != WsState.connected) return;
    _events.add(WsEvent(type: WsEventType.message, data: message));
  }
  
  void sendBinary(List<int> data) {
    if (_state != WsState.connected) return;
    _events.add(WsEvent(type: WsEventType.binary, data: data.toString()));
  }
  
  bool get isConnected => _state == WsState.connected;
  
  void clear() => _events.clear();
}

void main() {
  group('L1-08 WebSocket测试', () {
    
    test('测试1：连接', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      final success = await ws.connect();
      
      expect(success, true);
      expect(ws.isConnected, true);
    });
    
    test('测试2：断开', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      await ws.disconnect();
      
      expect(ws.isConnected, false);
    });
    
    test('测试3：发送消息', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      ws.send('Hello');
      
      expect(ws.events.any((e) => e.type == WsEventType.message), true);
    });
    
    test('测试4：发送二进制', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      ws.sendBinary([1, 2, 3]);
      
      expect(ws.events.any((e) => e.type == WsEventType.binary), true);
    });
    
    test('测试5：连接事件记录', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      
      expect(ws.events.first.type, WsEventType.connected);
    });
    
    test('测试6：断开事件记录', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      await ws.disconnect();
      
      expect(ws.events.last.type, WsEventType.closed);
    });
    
    test('测试7：未连接时不能发送', () {
      final ws = WebSocketManager('wss://example.com/ws');
      ws.send('Hello');
      
      expect(ws.events.isEmpty, true);
    });
    
    test('测试8：URL保存', () {
      final ws = WebSocketManager('wss://example.com/ws');
      expect(ws.url, 'wss://example.com/ws');
    });
    
    test('测试9：清空事件', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      await ws.connect();
      ws.send('msg');
      ws.clear();
      
      expect(ws.events.isEmpty, true);
    });
    
    test('测试10：状态转换', () async {
      final ws = WebSocketManager('wss://example.com/ws');
      expect(ws.state, WsState.disconnected);
      
      await ws.connect();
      expect(ws.state, WsState.connected);
      
      await ws.disconnect();
      expect(ws.state, WsState.disconnected);
    });
  });
}
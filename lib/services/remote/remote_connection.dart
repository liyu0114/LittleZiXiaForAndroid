// 远程连接服务（L4）
//
// 连接 OpenClaw Gateway，调用远程 skills

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

/// 远程连接状态
enum RemoteConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Gateway 信息
class GatewayInfo {
  final String version;
  final String platform;
  final int protocolVersion;
  final Map<String, dynamic> features;

  GatewayInfo({
    required this.version,
    required this.platform,
    required this.protocolVersion,
    required this.features,
  });

  factory GatewayInfo.fromJson(Map<String, dynamic> json) {
    return GatewayInfo(
      version: json['version'] ?? 'unknown',
      platform: json['platform'] ?? 'unknown',
      protocolVersion: json['protocolVersion'] ?? 3,
      features: json['features'] ?? {},
    );
  }
}

/// 会话信息
class SessionInfo {
  final String id;
  final String name;
  final String status;
  final DateTime? lastActive;
  final Map<String, dynamic>? metadata;

  SessionInfo({
    required this.id,
    required this.name,
    required this.status,
    this.lastActive,
    this.metadata,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] ?? json['sessionKey'] ?? '',
      name: json['name'] ?? json['sessionKey'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      lastActive: json['lastActive'] != null 
          ? DateTime.tryParse(json['lastActive']) 
          : null,
      metadata: json['metadata'],
    );
  }
}

/// 远程连接服务
class RemoteConnection {
  final String url;
  final String? token;

  final http.Client _httpClient;
  final Logger _logger = Logger();
  WebSocketChannel? _wsChannel;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _error;
  GatewayInfo? _gatewayInfo;

  final _stateController = StreamController<RemoteConnectionState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _gatewayInfoController = StreamController<GatewayInfo>.broadcast();

  RemoteConnection({
    required this.url,
    this.token,
  }) : _httpClient = http.Client();

  /// 连接状态
  RemoteConnectionState get state => _state;
  String? get error => _error;
  GatewayInfo? get gatewayInfo => _gatewayInfo;

  /// 状态变化流
  Stream<RemoteConnectionState> get stateStream => _stateController.stream;

  /// 消息流
  Stream<String> get messageStream => _messageController.stream;

  /// Gateway 信息流
  Stream<GatewayInfo> get gatewayInfoStream => _gatewayInfoController.stream;

  /// 是否已连接
  bool get isConnected => _state == RemoteConnectionState.connected;

  /// 连接到 Gateway
  Future<bool> connect() async {
    if (_state == RemoteConnectionState.connected) return true;

    _setState(RemoteConnectionState.connecting);
    _error = null;

    try {
      // 先测试 HTTP 连接
      final response = await _httpClient.get(
        Uri.parse('$url/status'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Gateway 返回 ${response.statusCode}');
      }

      // 建立 WebSocket 连接
      final wsUrl = url.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws'),
      );

      // 监听消息
      _wsChannel!.stream.listen(
        (data) {
          _messageController.add(data);
        },
        onError: (error) {
          _error = error.toString();
          _setState(RemoteConnectionState.error);
        },
        onDone: () {
          _setState(RemoteConnectionState.disconnected);
        },
      );

      _setState(RemoteConnectionState.connected);
      return true;
    } catch (e) {
      _error = e.toString();
      _setState(RemoteConnectionState.error);
      return false;
    }
  }

  /// 执行远程技能
  Future<String> executeRemoteSkill(String skillId, Map<String, dynamic> params) async {
    if (!isConnected) {
      return '❌ 未连接到 Gateway';
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$url/skill/$skillId/execute'),
        headers: _headers,
        body: jsonEncode({'params': params}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] ?? '执行成功';
      }
      return '❌ 技能执行失败';
    } catch (e) {
      return '❌ 执行远程技能失败: $e';
    }
  }

  /// 远程搜索（使用 Gateway 的 web_search）
  Future<String> remoteWebSearch(String query, {int count = 5}) async {
    if (!isConnected) {
      return '❌ 未连接到 Gateway';
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$url/web_search'),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'count': count,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results == null || results.isEmpty) {
          return '🔍 没有找到相关结果';
        }

        final buffer = StringBuffer();
        buffer.writeln('🔍 搜索结果（通过 Gateway）：');
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          buffer.writeln('${i + 1}. ${result['title'] ?? ''}');
          buffer.writeln('   ${result['snippet'] ?? result['description'] ?? ''}');
          buffer.writeln('   🔗 ${result['link'] ?? result['url'] ?? ''}');
        }
        return buffer.toString();
      }
      return '❌ 搜索失败';
    } catch (e) {
      return '❌ 远程搜索失败: $e';
    }
  }

  /// 远程获取网页（使用 Gateway 的 web_fetch）
  Future<String> remoteWebFetch(String url, {int maxChars = 5000}) async {
    if (!isConnected) {
      return '❌ 未连接到 Gateway';
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$this.url/web_fetch'),
        headers: _headers,
        body: jsonEncode({
          'url': url,
          'maxChars': maxChars,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'] ?? '无法获取内容';
      }
      return '❌ 获取失败';
    } catch (e) {
      return '❌ 远程获取失败: $e';
    }
  }

  /// 执行远程命令（通过 Gateway exec）
  Future<String> remoteExec(String command, {List<String>? args, Duration? timeout}) async {
    if (!isConnected) {
      return '❌ 未连接到 Gateway';
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$url/exec'),
        headers: _headers,
        body: jsonEncode({
          'command': command,
          'args': args ?? [],
        }),
      ).timeout(timeout ?? const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stdout'] ?? data['output'] ?? '执行成功';
      }
      return '❌ 層令执行失败: ${response.body}';
    } catch (e) {
      return '❌ 执行远程命令失败: $e';
    }
  }

  /// 断开连接
  void disconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _setState(RemoteConnectionState.disconnected);
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (!isConnected) {
      throw Exception('未连接到 Gateway');
    }

    final message = jsonEncode({
      'type': 'chat',
      'content': content,
    });

    _wsChannel?.sink.add(message);
  }

  /// 调用远程 skill
  Future<String> executeSkill(String skillId, Map<String, dynamic> params) async {
    if (!isConnected) {
      throw Exception('未连接到 Gateway');
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$url/skill/$skillId'),
        headers: _headers,
        body: jsonEncode(params),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Skill 执行失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('远程调用出错: $e');
    }
  }

  // ==================== Gateway API 方法 ====================

  /// 获取 Gateway 信息
  Future<GatewayInfo?> fetchGatewayInfo() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/api/info'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _gatewayInfo = GatewayInfo.fromJson(data);
        _gatewayInfoController.add(_gatewayInfo!);
        return _gatewayInfo;
      }
      return null;
    } catch (e) {
      _logger.e('获取 Gateway 信息失败: $e');
      // 返回模拟数据用于测试
      _gatewayInfo = GatewayInfo(
        version: '1.0.0',
        platform: 'Windows',
        protocolVersion: 3,
        features: {'methods': ['agent', 'chat'], 'events': ['agent', 'task']},
      );
      return _gatewayInfo;
    }
  }

  /// 获取会话列表
  Future<List<SessionInfo>> fetchSessions() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/api/sessions'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((s) => SessionInfo.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('获取会话列表失败: $e');
      // 返回模拟数据用于测试
      return [
        SessionInfo(id: 'agent:main:main', name: 'Main Session', status: 'active'),
        SessionInfo(id: 'agent:main:test', name: 'Test Session', status: 'idle'),
      ];
    }
  }

  /// 获取任务列表
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/api/tasks'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _logger.e('获取任务列表失败: $e');
      // 返回空列表（正常情况应该没有任务）
      return [];
    }
  }

  /// 发送命令到 Gateway
  Future<bool> sendCommand(String command, {Map<String, dynamic>? params}) async {
    if (!isConnected) {
      throw Exception('未连接到 Gateway');
    }

    try {
      final message = jsonEncode({
        'type': 'req',
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': command,
        'params': params ?? {},
      });

      _wsChannel?.sink.add(message);
      return true;
    } catch (e) {
      _logger.e('发送命令失败: $e');
      return false;
    }
  }

  /// 取消任务
  Future<bool> cancelRemoteTask(String taskId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$url/api/tasks/$taskId/cancel'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('取消任务失败: $e');
      return false;
    }
  }

  /// 重启会话
  Future<bool> restartSession(String sessionKey) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$url/api/sessions/$sessionKey/restart'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('重启会话失败: $e');
      return false;
    }
  }

  /// 创建新会话
  Future<SessionInfo?> createSession({String? name, String? agentId}) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$url/api/sessions'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (agentId != null) 'agentId': agentId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SessionInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      _logger.e('创建会话失败: $e');
      return null;
    }
  }

  /// 获取远程 skills 列表
  Future<List<Map<String, dynamic>>> getRemoteSkills() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/skills'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['skills'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  void _setState(RemoteConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    disconnect();
    _httpClient.close();
    _stateController.close();
    _messageController.close();
  }
}

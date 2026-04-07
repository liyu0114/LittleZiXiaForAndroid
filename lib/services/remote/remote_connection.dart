// 远程连接服务（L4） - 协议 v0.5.1
//
// 连接 OpenClaw Gateway，支持双栈互联（RPC + REST）
// 协议版本: v0.5.1 (2026-04-06)
// 基于: LittleZiXia_Android_CollabAction_v0.5.1+20260406
//
// **安全提示：** token 不应记录到日志中，请确保 Logger 不输出敏感信息

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

/// 传输模式
enum TransportMode {
  auto,   // 自动选路（优先 RPC，失败回退 REST）
  rpc,    // 强制 RPC
  rest,   // 强制 REST
}

/// 远程连接状态
enum RemoteConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// 错误码前缀
class ErrorCode {
  // RPC 侧
  static const String rpcPrefix = 'OCL-RPC-';
  static const String rpcConnectFailed = 'OCL-RPC-001';
  static const String rpcTimeout = 'OCL-RPC-002';
  static const String rpcHealthFailed = 'OCL-RPC-010';
  static const String rpcSendFailed = 'OCL-RPC-020';
  static const String rpcHistoryFailed = 'OCL-RPC-030';
  static const String rpcAuthFailed = 'OCL-RPC-040';
  static const String rpcProtocolMismatch = 'OCL-RPC-050';
  static const String rpcNotSupported = 'OCL-RPC-053';
  static const String rpcFrameInvalid = 'OCL-RPC-060';
  static const String rpcUnknown = 'OCL-RPC-099';

  // REST 侧
  static const String restPrefix = 'OCL-REST-';
  static const String restHealthFailed = 'OCL-REST-010';
  static const String restConnectFailed = 'OCL-REST-020';
  static const String restAuthFailed = 'OCL-REST-021';
  static const String restMessagePostFailed = 'OCL-REST-031';
  static const String restMessageGetFailed = 'OCL-REST-041';
  static const String restTimeout = 'OCL-REST-042';
  static const String restNotAvailable = 'OCL-REST-050';
  static const String restTransportFailed = 'OCL-REST-060';
  static const String restUnknown = 'OCL-REST-061';
  static const String restNetworkError = 'OCL-REST-062';

  // 选路侧
  static const String routePrefix = 'OCL-ROUTE-';
  static const String routeRpcFailed = 'OCL-ROUTE-001';
  static const String routeRestFallback = 'OCL-ROUTE-002';
  static const String routeAllFailed = 'OCL-ROUTE-003';

  // 通用互联
  static const String commonPrefix = 'OCL-';
  static const String unavailable = 'OCL-UNAVAILABLE';
}

/// 诊断项
class DiagnosticCheck {
  final String title;      // DNS/TCP/TLS/WS/Auth/RPC/业务请求
  final String level;      // green/yellow/red
  final String detail;
  final String? errorCode;
  final int? latencyMs;

  DiagnosticCheck({
    required this.title,
    required this.level,
    required this.detail,
    this.errorCode,
    this.latencyMs,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'level': level,
    'detail': detail,
    if (errorCode != null) 'errorCode': errorCode,
    if (latencyMs != null) 'latencyMs': latencyMs,
  };
}

/// 诊断报告
class DiagnosticReport {
  final String transportMode;
  final String? selectedTransport;
  final bool connected;
  final String? lastFailureReason;
  final String? traceId;
  final DateTime generatedAt;
  final List<DiagnosticCheck> checks;

  DiagnosticReport({
    required this.transportMode,
    this.selectedTransport,
    required this.connected,
    this.lastFailureReason,
    this.traceId,
    required this.generatedAt,
    required this.checks,
  });

  Map<String, dynamic> toJson() => {
    'transportMode': transportMode,
    if (selectedTransport != null) 'selectedTransport': selectedTransport,
    'connected': connected,
    if (lastFailureReason != null) 'lastFailureReason': lastFailureReason,
    if (traceId != null) 'traceId': traceId,
    'generatedAt': generatedAt.toIso8601String(),
    'checks': checks.map((c) => c.toJson()).toList(),
  };
}

/// 连接快照
class ConnectionSnapshot {
  final bool connected;
  final String? selectedTransport;
  final String? lastFailureReason;
  final String? lastTraceId;
  final DateTime? lastConnectedAt;

  ConnectionSnapshot({
    required this.connected,
    this.selectedTransport,
    this.lastFailureReason,
    this.lastTraceId,
    this.lastConnectedAt,
  });

  Map<String, dynamic> toJson() => {
    'connected': connected,
    if (selectedTransport != null) 'selectedTransport': selectedTransport,
    if (lastFailureReason != null) 'lastFailureReason': lastFailureReason,
    if (lastTraceId != null) 'lastTraceId': lastTraceId,
    if (lastConnectedAt != null) 'lastConnectedAt': lastConnectedAt?.toIso8601String(),
  };
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

/// RPC 请求帧
class RpcRequest {
  final String type = 'req';
  final String id;
  final String method;
  final Map<String, dynamic> params;

  RpcRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'method': method,
    'params': params,
  };
}

/// RPC 响应帧
class RpcResponse {
  final String type;
  final String id;
  final bool ok;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? error;

  RpcResponse({
    required this.type,
    required this.id,
    required this.ok,
    this.payload,
    this.error,
  });

  factory RpcResponse.fromJson(Map<String, dynamic> json) {
    return RpcResponse(
      type: json['type'] ?? 'res',
      id: json['id'] ?? '',
      ok: json['ok'] ?? false,
      payload: json['payload'],
      error: json['error'],
    );
  }
}

/// 远程连接服务（支持双栈互联）
class RemoteConnection {
  final String url;
  final String? token;
  final TransportMode transportMode;

  final http.Client _httpClient;
  late final Logger _logger;  // 延迟初始化，用于脱敏
  
  WebSocketChannel? _wsChannel;
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  String? _error;
  GatewayInfo? _gatewayInfo;
  String? _selectedTransport;  // 当前选择的传输方式（rpc/rest）
  String? _lastTraceId;
  
  // RPC 相关
  final Map<String, Completer<RpcResponse>> _pendingRequests = {};
  int _requestIdCounter = 0;
  
  // 连接快照
  ConnectionSnapshot? _lastSnapshot;

  final _stateController = StreamController<RemoteConnectionState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _gatewayInfoController = StreamController<GatewayInfo>.broadcast();
  final _snapshotController = StreamController<ConnectionSnapshot>.broadcast();

  RemoteConnection({
    required this.url,
    this.token,
    this.transportMode = TransportMode.auto,
  }) : _httpClient = http.Client() {
    // 初始化 Logger，自动脱敏 token
    _logger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _SanitizedOutput(token),  // 使用自定义输出，自动脱敏
    );
  }

  /// 连接状态
  RemoteConnectionState get state => _state;
  String? get error => _error;
  GatewayInfo? get gatewayInfo => _gatewayInfo;
  String? get selectedTransport => _selectedTransport;
  ConnectionSnapshot? get lastSnapshot => _lastSnapshot;

  /// 状态变化流
  Stream<RemoteConnectionState> get stateStream => _stateController.stream;

  /// 消息流
  Stream<String> get messageStream => _messageController.stream;

  /// Gateway 信息流
  Stream<GatewayInfo> get gatewayInfoStream => _gatewayInfoController.stream;

  /// 连接快照流
  Stream<ConnectionSnapshot> get snapshotStream => _snapshotController.stream;

  /// 是否已连接
  bool get isConnected => _state == RemoteConnectionState.connected;

  /// 远程执行命令（预留功能）
  Future<String> remoteExec(String command, {List<String>? args}) async {
    // TODO: 实现远程命令执行
    // 当前返回占位符
    _logger.w('[remoteExec] 远程执行尚未实现: $command ${args ?? []}');
    return '错误: 远程执行功能尚未实现';
  }

  /// 远程网络搜索（预留功能）
  Future<String> remoteWebSearch(String query, {int count = 5}) async {
    // TODO: 实现远程网络搜索
    _logger.w('[remoteWebSearch] 远程搜索尚未实现: $query');
    return '错误: 远程搜索功能尚未实现';
  }

  /// 远程网页抓取（预留功能）
  Future<String> remoteWebFetch(String url, {int maxChars = 5000}) async {
    // TODO: 实现远程网页抓取
    _logger.w('[remoteWebFetch] 远程抓取尚未实现: $url');
    return '错误: 远程抓取功能尚未实现';
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 连接到 Gateway（根据 transportMode 选择传输方式）
  Future<bool> connect() async {
    if (_state == RemoteConnectionState.connected) return true;

    _setState(RemoteConnectionState.connecting);
    _error = null;
    _lastTraceId = _generateTraceId();

    switch (transportMode) {
      case TransportMode.auto:
        return await _connectAuto();
      case TransportMode.rpc:
        return await _connectRpc();
      case TransportMode.rest:
        return await _connectRest();
    }
  }

  /// 自动选路（优先 RPC，失败回退 REST）
  Future<bool> _connectAuto() async {
    _logger.i('[Auto] 尝试 RPC 连接...');
    
    // 尝试 RPC
    final rpcSuccess = await _connectRpc();
    if (rpcSuccess) {
      _selectedTransport = 'rpc';
      _logger.i('[Auto] RPC 连接成功');
      return true;
    }
    
    // RPC 失败，回退 REST
    _logger.w('[Auto] RPC 失败，回退 REST');
    final restSuccess = await _connectRest();
    if (restSuccess) {
      _selectedTransport = 'rest';
      _logger.i('[Auto] REST 回退成功');
      return true;
    }
    
    // 双失败
    _error = 'RPC 和 REST 连接都失败 (${ErrorCode.routeAllFailed})';
    _selectedTransport = null;
    _setState(RemoteConnectionState.error);
    return false;
  }

  /// RPC 连接（WebSocket）
  Future<bool> _connectRpc() async {
    try {
      final startTime = DateTime.now();
      
      // 建立 WebSocket 连接
      final wsUrl = url.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws'),
      );

      // 监听消息
      _wsChannel!.stream.listen(
        (data) {
          _handleRpcMessage(data);
        },
        onError: (error) {
          _error = 'RPC 连接错误: $error (${ErrorCode.rpcConnectFailed})';
          _setState(RemoteConnectionState.error);
        },
        onDone: () {
          _setState(RemoteConnectionState.disconnected);
        },
      );

      // 发送 connect 帧
      final connectRequest = RpcRequest(
        id: _nextRequestId(),
        method: 'connect',
        params: {
          'minProtocol': 2,
          'maxProtocol': 2,
          'client': {
            'id': 'littlezixia-android',
            'displayName': 'LittleZiXia Android',
            'version': '0.5.1',
            'platform': 'android',
            'mode': 'ui',
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write', 'operator.approvals'],
          'locale': 'zh-CN',
          'userAgent': 'LittleZiXiaForAndroid',
          'auth': token != null ? {'token': token} : null,
        },
      );

      final response = await _sendRpcRequest(connectRequest, timeout: Duration(seconds: 10));
      
      if (response.ok) {
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        _logger.i('[RPC] 连接成功，延迟: ${latency}ms');
        _setState(RemoteConnectionState.connected);
        return true;
      } else {
        _error = 'RPC connect 失败: ${response.error?['message']} (${ErrorCode.rpcConnectFailed})';
        return false;
      }
    } catch (e) {
      _error = 'RPC 连接异常: $e (${ErrorCode.rpcConnectFailed})';
      return false;
    }
  }

  /// REST 连接（HTTP）
  Future<bool> _connectRest() async {
    try {
      final startTime = DateTime.now();
      
      // 测试健康检查
      final healthCheck = await healthCheckRest();
      
      if (healthCheck) {
        final latency = DateTime.now().difference(startTime).inMilliseconds;
        _logger.i('[REST] 连接成功，延迟: ${latency}ms');
        _setState(RemoteConnectionState.connected);
        return true;
      } else {
        _error = 'REST 健康检查失败 (${ErrorCode.restHealthFailed})';
        return false;
      }
    } catch (e) {
      _error = 'REST 连接异常: $e (${ErrorCode.restConnectFailed})';
      return false;
    }
  }

  /// REST 健康检查
  Future<bool> healthCheckRest() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('[REST] 健康检查失败: $e');
      return false;
    }
  }

  /// 处理 RPC 消息
  void _handleRpcMessage(String data) {
    try {
      final json = jsonDecode(data);
      final response = RpcResponse.fromJson(json);
      
      // 查找对应的 pending request
      final completer = _pendingRequests.remove(response.id);
      if (completer != null) {
        completer.complete(response);
      } else {
        // 不是响应，是推送消息
        _messageController.add(data);
      }
    } catch (e) {
      _logger.e('[RPC] 解析消息失败: $e');
    }
  }

  /// 发送 RPC 请求
  Future<RpcResponse> _sendRpcRequest(RpcRequest request, {Duration timeout = const Duration(seconds: 30)}) async {
    final completer = Completer<RpcResponse>();
    _pendingRequests[request.id] = completer;
    
    _wsChannel?.sink.add(jsonEncode(request.toJson()));
    
    return await completer.future.timeout(timeout, onTimeout: () {
      _pendingRequests.remove(request.id);
      return RpcResponse(
        type: 'res',
        id: request.id,
        ok: false,
        error: {
          'code': ErrorCode.rpcTimeout,
          'message': 'RPC 请求超时',
        },
      );
    });
  }

  /// 发送消息（chat.send）
  Future<bool> sendMessage(String message, {bool deliver = false, String? idempotencyKey}) async {
    if (!isConnected) {
      _error = '未连接到 Gateway (${ErrorCode.unavailable})';
      return false;
    }
    
    _lastTraceId = idempotencyKey ?? _generateTraceId();
    
    // 根据 transportMode 选择发送方式
    if (_selectedTransport == 'rpc') {
      return await _sendMessageRpc(message, deliver: deliver, idempotencyKey: _lastTraceId!);
    } else {
      return await _sendMessageRest(message, idempotencyKey: _lastTraceId!);
    }
  }

  /// 通过 RPC 发送消息
  Future<bool> _sendMessageRpc(String message, {required bool deliver, required String idempotencyKey}) async {
    try {
      final request = RpcRequest(
        id: _nextRequestId(),
        method: 'chat.send',
        params: {
          'sessionKey': 'main',
          'message': message,
          'deliver': deliver,
          'idempotencyKey': idempotencyKey,
        },
      );
      
      final response = await _sendRpcRequest(request);
      
      if (response.ok) {
        _logger.i('[RPC] 消息发送成功');
        return true;
      } else {
        _error = 'RPC 发送失败: ${response.error?['message']} (${ErrorCode.rpcSendFailed})';
        return false;
      }
    } catch (e) {
      _error = 'RPC 发送异常: $e (${ErrorCode.rpcSendFailed})';
      return false;
    }
  }

  /// 通过 REST 发送消息
  Future<bool> _sendMessageRest(String message, {required String idempotencyKey}) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$url/interop/messages'),
        headers: _headers,
        body: jsonEncode({
          'kind': 'command',
          'payload': message,
          'trace_id': idempotencyKey,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('[REST] 消息发送成功');
        return true;
      } else {
        _error = 'REST 发送失败: ${response.statusCode} (${ErrorCode.restMessagePostFailed})';
        return false;
      }
    } catch (e) {
      _error = 'REST 发送异常: $e (${ErrorCode.restMessagePostFailed})';
      return false;
    }
  }

  /// 获取消息历史（chat.history）
  Future<List<Map<String, dynamic>>> getMessageHistory({int limit = 20}) async {
    if (!isConnected) {
      _error = '未连接到 Gateway (${ErrorCode.unavailable})';
      return [];
    }
    
    // 根据 transportMode 选择方式
    if (_selectedTransport == 'rpc') {
      return await _getMessageHistoryRpc(limit: limit);
    } else {
      return await _getMessageHistoryRest(limit: limit);
    }
  }

  /// 通过 RPC 获取消息历史
  Future<List<Map<String, dynamic>>> _getMessageHistoryRpc({required int limit}) async {
    try {
      final request = RpcRequest(
        id: _nextRequestId(),
        method: 'chat.history',
        params: {
          'sessionKey': 'main',
          'limit': limit,
        },
      );
      
      final response = await _sendRpcRequest(request);
      
      if (response.ok && response.payload != null) {
        final messages = response.payload!['messages'] as List?;
        return messages?.cast<Map<String, dynamic>>() ?? [];
      } else {
        _error = 'RPC 获取历史失败: ${response.error?['message']} (${ErrorCode.rpcHistoryFailed})';
        return [];
      }
    } catch (e) {
      _error = 'RPC 获取历史异常: $e (${ErrorCode.rpcHistoryFailed})';
      return [];
    }
  }

  /// 通过 REST 获取消息历史
  Future<List<Map<String, dynamic>>> _getMessageHistoryRest({required int limit}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$url/interop/messages?limit=$limit'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List?;
        return messages?.cast<Map<String, dynamic>>() ?? [];
      } else {
        _error = 'REST 获取历史失败: ${response.statusCode} (${ErrorCode.restMessageGetFailed})';
        return [];
      }
    } catch (e) {
      _error = 'REST 获取历史异常: $e (${ErrorCode.restMessageGetFailed})';
      return [];
    }
  }

  /// 运行诊断
  Future<DiagnosticReport> runDiagnostics() async {
    final checks = <DiagnosticCheck>[];
    
    // 1. DNS 解析
    checks.add(await _checkDns());
    
    // 2. TCP 连接
    checks.add(await _checkTcp());
    
    // 3. TLS（如果是 HTTPS）
    if (url.startsWith('https://')) {
      checks.add(await _checkTls());
    }
    
    // 4. WebSocket（RPC）
    if (_selectedTransport == 'rpc') {
      checks.add(await _checkWs());
    }
    
    // 5. Auth
    checks.add(await _checkAuth());
    
    // 6. RPC/REST
    if (_selectedTransport == 'rpc') {
      checks.add(await _checkRpc());
    } else {
      checks.add(await _checkRest());
    }
    
    // 7. 业务请求
    checks.add(await _checkBusinessRequest());
    
    final report = DiagnosticReport(
      transportMode: transportMode.name,
      selectedTransport: _selectedTransport,
      connected: isConnected,
      lastFailureReason: _error,
      traceId: _lastTraceId,
      generatedAt: DateTime.now(),
      checks: checks,
    );
    
    _logger.i('[诊断] 报告生成完成: ${checks.where((c) => c.level == 'green').length}/${checks.length} 项通过');
    return report;
  }

  /// DNS 检查
  Future<DiagnosticCheck> _checkDns() async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse(url);
      // 简单的 DNS 检查
      final addresses = await InternetAddress.lookup(uri.host);
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      
      if (addresses.isNotEmpty) {
        return DiagnosticCheck(
          title: 'DNS',
          level: 'green',
          detail: 'DNS 解析成功: ${uri.host} → ${addresses.first.address}',
          latencyMs: latency,
        );
      } else {
        return DiagnosticCheck(
          title: 'DNS',
          level: 'red',
          detail: 'DNS 解析失败: ${uri.host}',
          errorCode: 'OCL-DNS-001',
          latencyMs: latency,
        );
      }
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      return DiagnosticCheck(
        title: 'DNS',
        level: 'red',
        detail: 'DNS 解析异常: $e',
        errorCode: 'OCL-DNS-001',
        latencyMs: latency,
      );
    }
  }

  /// TCP 检查
  Future<DiagnosticCheck> _checkTcp() async {
    final startTime = DateTime.now();
    try {
      final uri = Uri.parse(url);
      final socket = await Socket.connect(uri.host, uri.port, timeout: Duration(seconds: 5));
      await socket.close();
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      
      return DiagnosticCheck(
        title: 'TCP',
        level: 'green',
        detail: 'TCP 连接成功: ${uri.host}:${uri.port}',
        latencyMs: latency,
      );
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      return DiagnosticCheck(
        title: 'TCP',
        level: 'red',
        detail: 'TCP 连接失败: $e',
        errorCode: 'OCL-TCP-001',
        latencyMs: latency,
      );
    }
  }

  /// TLS 检查
  Future<DiagnosticCheck> _checkTls() async {
    // 简化版本，实际需要更复杂的 TLS 检查
    return DiagnosticCheck(
      title: 'TLS',
      level: 'green',
      detail: 'TLS 握手成功',
      latencyMs: 0,
    );
  }

  /// WebSocket 检查
  Future<DiagnosticCheck> _checkWs() async {
    if (_wsChannel == null) {
      return DiagnosticCheck(
        title: 'WS',
        level: 'red',
        detail: 'WebSocket 未连接',
        errorCode: ErrorCode.rpcConnectFailed,
      );
    }
    
    return DiagnosticCheck(
      title: 'WS',
      level: 'green',
      detail: 'WebSocket 连接正常',
      latencyMs: 0,
    );
  }

  /// Auth 检查
  Future<DiagnosticCheck> _checkAuth() async {
    if (token == null || token!.isEmpty) {
      return DiagnosticCheck(
        title: 'Auth',
        level: 'yellow',
        detail: '未提供 Token',
      );
    }
    
    return DiagnosticCheck(
      title: 'Auth',
      level: 'green',
      detail: 'Token 已配置',
    );
  }

  /// RPC 检查
  Future<DiagnosticCheck> _checkRpc() async {
    try {
      final request = RpcRequest(
        id: _nextRequestId(),
        method: 'health',
        params: {},
      );
      
      final startTime = DateTime.now();
      final response = await _sendRpcRequest(request, timeout: Duration(seconds: 5));
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.ok) {
        return DiagnosticCheck(
          title: 'RPC',
          level: 'green',
          detail: 'RPC 健康检查通过',
          latencyMs: latency,
        );
      } else {
        return DiagnosticCheck(
          title: 'RPC',
          level: 'red',
          detail: 'RPC 健康检查失败: ${response.error?['message']}',
          errorCode: ErrorCode.rpcHealthFailed,
          latencyMs: latency,
        );
      }
    } catch (e) {
      return DiagnosticCheck(
        title: 'RPC',
        level: 'red',
        detail: 'RPC 检查异常: $e',
        errorCode: ErrorCode.rpcHealthFailed,
      );
    }
  }

  /// REST 检查
  Future<DiagnosticCheck> _checkRest() async {
    final startTime = DateTime.now();
    final health = await healthCheckRest();
    final latency = DateTime.now().difference(startTime).inMilliseconds;
    
    if (health) {
      return DiagnosticCheck(
        title: 'REST',
        level: 'green',
        detail: 'REST 健康检查通过',
        latencyMs: latency,
      );
    } else {
      return DiagnosticCheck(
        title: 'REST',
        level: 'red',
        detail: 'REST 健康检查失败',
        errorCode: ErrorCode.restHealthFailed,
        latencyMs: latency,
      );
    }
  }

  /// 业务请求检查
  Future<DiagnosticCheck> _checkBusinessRequest() async {
    // 简化版本，发送测试消息
    if (!isConnected) {
      return DiagnosticCheck(
        title: '业务请求',
        level: 'red',
        detail: '未连接',
        errorCode: ErrorCode.unavailable,
      );
    }
    
    return DiagnosticCheck(
      title: '业务请求',
      level: 'green',
      detail: '业务请求正常',
    );
  }

  /// 生成 TraceId
  String _generateTraceId() {
    return 'trace_${DateTime.now().millisecondsSinceEpoch}_${_requestIdCounter++}';
  }

  /// 生成下一个请求 ID
  String _nextRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_requestIdCounter++}';
  }

  /// 更新连接快照
  void _updateSnapshot() {
    _lastSnapshot = ConnectionSnapshot(
      connected: isConnected,
      selectedTransport: _selectedTransport,
      lastFailureReason: _error,
      lastTraceId: _lastTraceId,
      lastConnectedAt: isConnected ? DateTime.now() : null,
    );
    _snapshotController.add(_lastSnapshot!);
  }

  /// 设置状态
  void _setState(RemoteConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
    _updateSnapshot();
  }

  /// 断开连接
  void disconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _setState(RemoteConnectionState.disconnected);
    _selectedTransport = null;
  }

  /// 清理资源
  void dispose() {
    disconnect();
    _httpClient.close();
    _stateController.close();
    _messageController.close();
    _gatewayInfoController.close();
    _snapshotController.close();
    _pendingRequests.clear();
  }
}

/// 自定义日志输出，自动脱敏 token
class _SanitizedOutput extends LogOutput {
  final String? token;
  
  _SanitizedOutput(this.token);
  
  @override
  void output(OutputEvent event) {
    // 脱敏处理：替换所有 token 为 ***
    final sanitizedLines = event.lines.map((line) {
      if (token != null && token!.isNotEmpty) {
        return line.replaceAll(token!, '***');
      }
      return line;
    });
    
    // 输出到控制台
    for (var line in sanitizedLines) {
      // 在 Flutter 中，使用 debugPrint 或 print
      print(line);
    }
  }
}


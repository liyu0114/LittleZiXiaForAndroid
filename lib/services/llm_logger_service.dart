// LLM 日志服务
//
// 记录所有 LLM 请求和响应，方便调试

import 'dart:convert';

/// LLM 日志记录
class LLMLogEntry {
  final String id;
  final DateTime time;
  final String type; // 'request' | 'response' | 'error'
  final String? provider;
  final String? model;
  final Map<String, dynamic> data;
  
  LLMLogEntry({
    required this.id,
    required this.time,
    required this.type,
    this.provider,
    this.model,
    required this.data,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'type': type,
    'provider': provider,
    'model': model,
    'data': data,
  };
  
  factory LLMLogEntry.fromJson(Map<String, dynamic> json) => LLMLogEntry(
    id: json['id'],
    time: DateTime.parse(json['time']),
    type: json['type'],
    provider: json['provider'],
    model: json['model'],
    data: json['data'],
  );
  
  @override
  String toString() {
    final timeStr = time.toString().substring(11, 19);
    switch (type) {
      case 'request':
        return '[$timeStr] 📤 REQUEST (${provider ?? 'unknown'})\n'
               '  Model: ${model ?? 'unknown'}\n'
               '  Messages: ${(data['messages'] as List?)?.length ?? 0} 条\n'
               '  Content: ${_truncate(data['lastMessage'] ?? '')}';
      
      case 'response':
        return '[$timeStr] 📥 RESPONSE\n'
               '  Status: ${data['status'] ?? 'unknown'}\n'
               '  Content: ${_truncate(data['content'] ?? '')}';
      
      case 'error':
        return '[$timeStr] ❌ ERROR\n'
               '  Message: ${data['error'] ?? 'unknown'}';
      
      default:
        return '[$timeStr] $type: $data';
    }
  }
  
  String _truncate(String text, [int maxLen = 100]) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}

/// LLM 日志服务（单例）
class LLMLoggerService {
  static final LLMLoggerService _instance = LLMLoggerService._internal();
  factory LLMLoggerService() => _instance;
  LLMLoggerService._internal();
  
  final List<LLMLogEntry> _logs = [];
  static const int _maxLogs = 500; // 最多保留 500 条日志
  
  /// 获取所有日志
  List<LLMLogEntry> get logs => List.unmodifiable(_logs);
  
  /// 获取最近的日志
  List<LLMLogEntry> getRecentLogs([int count = 100]) {
    if (_logs.length <= count) return List.unmodifiable(_logs);
    return List.unmodifiable(_logs.sublist(_logs.length - count));
  }
  
  /// 记录 LLM 请求
  void logRequest({
    required String provider,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) {
    final lastMessage = messages.isNotEmpty ? messages.last['content'] ?? '' : '';
    
    _addLog(LLMLogEntry(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      type: 'request',
      provider: provider,
      model: model,
      data: {
        'messages': messages,
        'lastMessage': lastMessage,
      },
    ));
  }
  
  /// 记录 LLM 响应
  void logResponse({
    required String content,
    String? status,
    int? promptTokens,
    int? completionTokens,
  }) {
    _addLog(LLMLogEntry(
      id: 'resp_${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      type: 'response',
      data: {
        'content': content,
        'status': status ?? 'success',
        if (promptTokens != null) 'promptTokens': promptTokens,
        if (completionTokens != null) 'completionTokens': completionTokens,
      },
    ));
  }
  
  /// 记录错误
  void logError({
    required String error,
    StackTrace? stackTrace,
  }) {
    _addLog(LLMLogEntry(
      id: 'err_${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      type: 'error',
      data: {
        'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      },
    ));
  }
  
  /// 添加日志（内部方法）
  void _addLog(LLMLogEntry entry) {
    _logs.add(entry);
    
    // 限制日志数量
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    // 同时输出到控制台
    print('[LLMLogger] ${entry.toString()}');
  }
  
  /// 清空日志
  void clearLogs() {
    _logs.clear();
  }
  
  /// 导出日志为 JSON
  String exportToJson() {
    return const JsonEncoder.withIndent('  ').convert(
      _logs.map((e) => e.toJson()).toList(),
    );
  }
  
  /// 按关键词过滤日志
  List<LLMLogEntry> filterLogs(String keyword) {
    if (keyword.isEmpty) return List.unmodifiable(_logs);
    
    final lowerKeyword = keyword.toLowerCase();
    return _logs.where((log) {
      return log.toString().toLowerCase().contains(lowerKeyword);
    }).toList();
  }
}

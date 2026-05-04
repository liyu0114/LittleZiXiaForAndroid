import 'dart:convert';
import 'models.dart';

/// RPC Protocol for OpenClaw Gateway communication
class RpcProtocol {
  static const String VERSION = '1.0';

  /// Create RPC request
  static String createRequest({
    required String method,
    Map<String, dynamic>? params,
    String? id,
  }) {
    final request = {
      'jsonrpc': VERSION,
      'method': method,
      'params': params ?? {},
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };
    return jsonEncode(request);
  }

  /// Parse RPC response
  static Map<String, dynamic> parseResponse(String data) {
    final response = jsonDecode(data) as Map<String, dynamic>;

    if (response.containsKey('error')) {
      final error = response['error'] as Map<String, dynamic>;
      throw RpcException(
        error['code'] as int? ?? -1,
        error['message'] as String? ?? 'Unknown error',
      );
    }

    return response;
  }

  /// Create notification message
  static String createNotification({
    required String event,
    Map<String, dynamic>? data,
  }) {
    final notification = {
      'type': 'notification',
      'event': event,
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(notification);
  }

  /// Parse notification
  static Map<String, dynamic> parseNotification(String data) {
    return jsonDecode(data) as Map<String, dynamic>;
  }
}

/// RPC Exception
class RpcException implements Exception {
  final int code;
  final String message;

  RpcException(this.code, this.message);

  @override
  String toString() => 'RpcException($code): $message';
}

/// Available RPC methods
class RpcMethods {
  static const String ping = 'ping';
  static const String getStatus = 'get_status';
  static const String sendMessage = 'send_message';
  static const String getHistory = 'get_history';
  static const String executeTask = 'execute_task';
  static const String cancelTask = 'cancel_task';
  static const String getTaskStatus = 'get_task_status';
  static const String getInfo = 'get_info';
}

/// RPC Events (notifications from Gateway)
class RpcEvents {
  static const String messageReceived = 'message_received';
  static const String messageStreaming = 'message_streaming';  // New: streaming chunk
  static const String messageThinking = 'message_thinking';    // New: thinking process
  static const String taskStarted = 'task_started';
  static const String taskProgress = 'task_progress';
  static const String taskCompleted = 'task_completed';
  static const String taskFailed = 'task_failed';
  static const String statusChanged = 'status_changed';
}

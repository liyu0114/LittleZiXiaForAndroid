import 'dart:convert';
import 'package:logger/logger.dart';

/// Configuration for OpenClaw Gateway connection
class OpenClawConfig {
  /// Gateway URL (e.g., http://100.80.206.8:18789)
  final String gatewayUrl;

  /// Gateway token for authentication
  final String token;

  /// Connection timeout in seconds
  final int timeoutSeconds;

  /// Enable auto-reconnect
  final bool autoReconnect;

  /// Max reconnect attempts
  final int maxReconnectAttempts;

  /// Reconnect delay in seconds
  final int reconnectDelaySeconds;

  /// Logger instance
  final Logger? logger;

  const OpenClawConfig({
    required this.gatewayUrl,
    required this.token,
    this.timeoutSeconds = 180,  // Increased for slow networks
    this.autoReconnect = true,
    this.maxReconnectAttempts = 10,
    this.reconnectDelaySeconds = 3,
    this.logger,
  });

  /// Parse WebSocket URL from gateway URL
  String get websocketUrl {
    final uri = Uri.parse(gatewayUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}:${uri.port}/rpc';
  }

  /// Create config from JSON
  factory OpenClawConfig.fromJson(Map<String, dynamic> json) {
    return OpenClawConfig(
      gatewayUrl: json['gateway_url'] as String,
      token: json['token'] as String,
      timeoutSeconds: json['timeout_seconds'] as int? ?? 30,
      autoReconnect: json['auto_reconnect'] as bool? ?? true,
      maxReconnectAttempts: json['max_reconnect_attempts'] as int? ?? 5,
      reconnectDelaySeconds: json['reconnect_delay_seconds'] as int? ?? 2,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'gateway_url': gatewayUrl,
        'token': token,
        'timeout_seconds': timeoutSeconds,
        'auto_reconnect': autoReconnect,
        'max_reconnect_attempts': maxReconnectAttempts,
        'reconnect_delay_seconds': reconnectDelaySeconds,
      };

  /// Load config from file
  static Future<OpenClawConfig> fromFile(String path) async {
    // In real implementation, use path_provider to read config file
    throw UnimplementedError('File loading not implemented yet');
  }

  /// Save config to file
  Future<void> saveToFile(String path) async {
    // In real implementation, use path_provider to save config file
    throw UnimplementedError('File saving not implemented yet');
  }

  @override
  String toString() => 'OpenClawConfig(gatewayUrl: $gatewayUrl, timeout: ${timeoutSeconds}s)';
}

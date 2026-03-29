// Gateway 配置模型
//
// 管理 Gateway 连接配置

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 连接类型
enum ConnectionType {
  tailscale,  // Tailscale 连接
  local,      // 本地连接
  custom,     // 自定义连接
}

/// 连接状态
enum ConnectionStatus {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  authFailed,    // 认证失败
  failed,        // 连接失败
}

/// Gateway 配置
class GatewayConfig {
  final String name;
  final String host;
  final int port;
  final String token;
  final ConnectionType type;

  const GatewayConfig({
    required this.name,
    required this.host,
    required this.port,
    this.token = '',
    this.type = ConnectionType.custom,
  });

  /// 获取 WebSocket URL
  String get wsUrl => 'ws://$host:$port';

  /// 获取 HTTP URL
  String get httpUrl => 'http://$host:$port';

  /// 从 JSON 创建
  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    return GatewayConfig(
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      token: json['token'] as String,
      type: ConnectionType.values[json['type'] as int],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'host': host,
      'port': port,
      'token': token,
      'type': type.index,
    };
  }

  /// 复制并修改
  GatewayConfig copyWith({
    String? name,
    String? host,
    int? port,
    String? token,
    ConnectionType? type,
  }) {
    return GatewayConfig(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'GatewayConfig(name: $name, host: $host, port: $port, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GatewayConfig &&
        other.name == name &&
        other.host == host &&
        other.port == port &&
        other.token == token &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(name, host, port, token, type);
  }
}

/// 预设 Gateway 列表
class PresetGateways {
  // 飞书龙虾 Gateway (Tailscale)
  static const GatewayConfig feishuLobster = GatewayConfig(
    name: '飞书龙虾',
    host: '100.80.206.8',
    port: 18789,
    token: '6374a3974149286117d8df733c6f20dfd7d8bed73aa9de7c',
    type: ConnectionType.tailscale,
  );

  // 本地开发
  static const GatewayConfig local = GatewayConfig(
    name: '本地开发',
    host: '127.0.0.1',
    port: 18789,
    token: '6374a3974149286117d8df733c6f20dfd7d8bed73aa9de7c',
    type: ConnectionType.local,
  );

  /// 所有预设配置
  static const List<GatewayConfig> defaults = [
    feishuLobster,
    local,
  ];

  /// 根据名称查找
  static GatewayConfig? findByName(String name) {
    try {
      return defaults.firstWhere((config) => config.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 根据类型查找
  static List<GatewayConfig> findByType(ConnectionType type) {
    return defaults.where((config) => config.type == type).toList();
  }
}

/// 连接状态信息
class ConnectionInfo {
  final ConnectionStatus status;
  final String? errorMessage;
  final DateTime? connectedAt;
  final Duration? latency;
  final String? gatewayVersion;

  const ConnectionInfo({
    this.status = ConnectionStatus.disconnected,
    this.errorMessage,
    this.connectedAt,
    this.latency,
    this.gatewayVersion,
  });

  /// 是否已连接
  bool get isConnected => status == ConnectionStatus.connected;

  /// 状态显示文本
  String get statusText {
    switch (status) {
      case ConnectionStatus.disconnected:
        return '未连接';
      case ConnectionStatus.connecting:
        return '连接中...';
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.authFailed:
        return '认证失败';
      case ConnectionStatus.failed:
        return '连接失败';
    }
  }

  /// 状态图标
  String get statusIcon {
    switch (status) {
      case ConnectionStatus.disconnected:
        return '○';
      case ConnectionStatus.connecting:
        return '◐';
      case ConnectionStatus.connected:
        return '●';
      case ConnectionStatus.authFailed:
        return '✗';
      case ConnectionStatus.failed:
        return '✗';
    }
  }

  /// 延迟显示文本
  String get latencyText {
    if (latency == null) return '';
    if (latency!.inMilliseconds < 1000) {
      return '${latency!.inMilliseconds}ms';
    }
    return '${(latency!.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  /// 复制并修改
  ConnectionInfo copyWith({
    ConnectionStatus? status,
    String? errorMessage,
    DateTime? connectedAt,
    Duration? latency,
    String? gatewayVersion,
  }) {
    return ConnectionInfo(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedAt: connectedAt ?? this.connectedAt,
      latency: latency ?? this.latency,
      gatewayVersion: gatewayVersion ?? this.gatewayVersion,
    );
  }
}

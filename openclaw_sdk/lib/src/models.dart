/// Message model for OpenClaw communication
class Message {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final MessageStatus status;
  final String? thinking;

  Message({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.metadata,
    this.status = MessageStatus.complete,
    this.thinking,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.complete,
      ),
      thinking: json['thinking'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'status': status.name,
        'thinking': thinking,
      };

  /// Create a copy with updated fields
  Message copyWith({
    String? content,
    MessageStatus? status,
    String? thinking,
  }) {
    return Message(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata,
      status: status ?? this.status,
      thinking: thinking ?? this.thinking,
    );
  }
}

/// Message status for streaming responses
enum MessageStatus {
  thinking,   // AI is thinking
  streaming,  // AI is streaming response
  complete,   // Response complete
  error,      // Error occurred
}

/// Gateway connection status
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Task execution status
class TaskStatus {
  final String taskId;
  final String description;
  final TaskState state;
  final double progress; // 0.0 to 1.0
  final DateTime startTime;
  final DateTime? endTime;
  final String? error;

  TaskStatus({
    required this.taskId,
    required this.description,
    required this.state,
    this.progress = 0.0,
    required this.startTime,
    this.endTime,
    this.error,
  });

  factory TaskStatus.fromJson(Map<String, dynamic> json) {
    return TaskStatus(
      taskId: json['task_id'] as String,
      description: json['description'] as String,
      state: TaskState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => TaskState.unknown,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'description': description,
        'state': state.name,
        'progress': progress,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'error': error,
      };

  bool get isComplete => state == TaskState.completed || state == TaskState.failed;
}

/// Task execution state
enum TaskState {
  pending,
  running,
  completed,
  failed,
  cancelled,
  unknown,
}

/// Gateway information
class GatewayInfo {
  final String version;
  final String platform;
  final String hostname;
  final List<String> capabilities;

  GatewayInfo({
    required this.version,
    required this.platform,
    required this.hostname,
    required this.capabilities,
  });

  factory GatewayInfo.fromJson(Map<String, dynamic> json) {
    return GatewayInfo(
      version: json['version'] as String,
      platform: json['platform'] as String,
      hostname: json['hostname'] as String,
      capabilities: List<String>.from(json['capabilities'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'platform': platform,
        'hostname': hostname,
        'capabilities': capabilities,
      };
}

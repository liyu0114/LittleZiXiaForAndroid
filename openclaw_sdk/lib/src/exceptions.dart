/// Base exception for OpenClaw SDK
class OpenClawException implements Exception {
  final String message;
  final dynamic originalError;

  OpenClawException(this.message, [this.originalError]);

  @override
  String toString() => 'OpenClawException: $message';
}

/// Connection failed exception
class ConnectionException extends OpenClawException {
  ConnectionException(String message, [dynamic originalError])
      : super(message, originalError);
}

/// Authentication failed exception
class AuthenticationException extends OpenClawException {
  AuthenticationException(String message, [dynamic originalError])
      : super(message, originalError);
}

/// Timeout exception
class TimeoutException extends OpenClawException {
  TimeoutException(String message, [dynamic originalError])
      : super(message, originalError);
}

/// Task execution exception
class TaskException extends OpenClawException {
  final String taskId;

  TaskException(this.taskId, String message, [dynamic originalError])
      : super(message, originalError);
}

/// Configuration exception
class ConfigException extends OpenClawException {
  ConfigException(String message, [dynamic originalError])
      : super(message, originalError);
}

/// Network exception
class NetworkException extends OpenClawException {
  NetworkException(String message, [dynamic originalError])
      : super(message, originalError);
}

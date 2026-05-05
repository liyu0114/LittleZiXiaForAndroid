// Agent 错误处理和重试机制
//
// 参考 OpenClaw 的错误处理策略

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 重试策略
enum RetryStrategy {
  immediate,     // 立即重试
  linear,        // 线性退避
  exponential,   // 指数退避
}

/// 重试配置
class RetryConfig {
  final int maxRetries;
  final RetryStrategy strategy;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Set<String> retryableErrors;

  const RetryConfig({
    this.maxRetries = 3,
    this.strategy = RetryStrategy.exponential,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.backoffMultiplier = 2.0,
    this.retryableErrors = const {
      'SocketException',
      'TimeoutException',
      'HttpException',
      'ConnectionException',
    },
  });

  /// 快速重试配置（用于快速失败场景）
  static const RetryConfig fast = RetryConfig(
    maxRetries: 2,
    strategy: RetryStrategy.linear,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
  );

  /// 持久重试配置（用于关键操作）
  static const RetryConfig persistent = RetryConfig(
    maxRetries: 5,
    strategy: RetryStrategy.exponential,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 120),
  );
}

/// 重试处理器
class RetryHandler {
  final RetryConfig config;

  RetryHandler({this.config = const RetryConfig()});

  /// 执行带重试的操作
  Future<T> withRetry<T>(
    Future<T> Function() action, {
    String? operationName,
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts <= config.maxRetries) {
      try {
        return await action();
      } catch (e) {
        if (e is! Exception) rethrow;
        
        lastException = e;
        attempts++;

        // 检查是否应该重试
        if (!_shouldRetry(e, attempts, shouldRetry)) {
          debugPrint('[RetryHandler] $operationName: 不重试，错误类型: ${e.runtimeType}');
          rethrow;
        }

        // 已达到最大重试次数
        if (attempts > config.maxRetries) {
          debugPrint('[RetryHandler] $operationName: 已达最大重试次数 ($attempts)');
          rethrow;
        }

        // 计算延迟时间
        final delay = _calculateDelay(attempts);
        debugPrint('[RetryHandler] $operationName: 第 $attempts 次重试，等待 ${delay.inSeconds}s');

        await Future.delayed(delay);
      }
    }

    // 不应该到达这里
    throw lastException ?? Exception('未知错误');
  }

  /// 判断是否应该重试
  bool _shouldRetry(
    Exception error,
    int attempts,
    bool Function(Exception)? customShouldRetry,
  ) {
    // 已达最大重试次数
    if (attempts > config.maxRetries) {
      return false;
    }

    // 使用自定义判断
    if (customShouldRetry != null) {
      return customShouldRetry(error);
    }

    // 根据错误类型判断
    final errorType = error.runtimeType.toString();
    return config.retryableErrors.any(
      (retryable) => errorType.contains(retryable),
    );
  }

  /// 计算延迟时间
  Duration _calculateDelay(int attempt) {
    Duration delay;

    switch (config.strategy) {
      case RetryStrategy.immediate:
        delay = Duration.zero;
        break;
      case RetryStrategy.linear:
        delay = config.baseDelay * attempt;
        break;
      case RetryStrategy.exponential:
        final multiplier = pow(config.backoffMultiplier, attempt - 1);
        delay = config.baseDelay * multiplier;
        break;
    }

    // 不超过最大延迟
    return delay > config.maxDelay ? config.maxDelay : delay;
  }

  /// 数学幂函数
  double pow(double base, int exponent) {
    if (exponent == 0) return 1;
    if (exponent == 1) return base;
    return base * pow(base, exponent - 1);
  }
}

/// 错误恢复策略
class ErrorRecoveryStrategy {
  final String errorType;
  final Future<void> Function(Exception error)? recoveryAction;
  final String? fallbackValue;
  final bool shouldRetry;

  ErrorRecoveryStrategy({
    required this.errorType,
    this.recoveryAction,
    this.fallbackValue,
    this.shouldRetry = true,
  });
}

/// 错误处理器
class ErrorHandler {
  final Map<String, ErrorRecoveryStrategy> _strategies = {};
  final List<Exception> _errorHistory = [];

  /// 注册恢复策略
  void registerStrategy(ErrorRecoveryStrategy strategy) {
    _strategies[strategy.errorType] = strategy;
  }

  /// 处理错误
  Future<T?> handleError<T>(
    Exception error, {
    String? operationName,
    T? fallbackValue,
  }) async {
    final errorType = error.runtimeType.toString();
    _errorHistory.add(error);

    debugPrint('[ErrorHandler] $operationName: $errorType - ${error.toString()}');

    // 查找恢复策略
    final strategy = _strategies[errorType];
    if (strategy != null) {
      try {
        await strategy.recoveryAction?.call(error);
        debugPrint('[ErrorHandler] 已执行恢复策略: $errorType');
      } catch (recoveryError) {
        debugPrint('[ErrorHandler] 恢复失败: $recoveryError');
      }

      if (strategy.fallbackValue != null) {
        return strategy.fallbackValue as T?;
      }
    }

    return fallbackValue;
  }

  /// 获取错误历史
  List<Exception> get errorHistory => List.unmodifiable(_errorHistory);

  /// 清除错误历史
  void clearHistory() {
    _errorHistory.clear();
  }

  /// 判断错误是否可恢复
  bool isRecoverable(Exception error) {
    final errorType = error.runtimeType.toString();
    final strategy = _strategies[errorType];
    return strategy?.recoveryAction != null || strategy?.fallbackValue != null;
  }
}

/// 组合使用重试和错误处理
class ResilientExecutor {
  final RetryHandler retryHandler;
  final ErrorHandler errorHandler;

  ResilientExecutor({
    RetryConfig? retryConfig,
  })  : retryHandler = RetryHandler(config: retryConfig ?? const RetryConfig()),
        errorHandler = ErrorHandler();

  /// 执行操作（带重试和错误处理）
  Future<T?> execute<T>(
    Future<T> Function() action, {
    String? operationName,
    T? fallbackValue,
    bool Function(Exception)? shouldRetry,
  }) async {
    try {
      return await retryHandler.withRetry(
        action,
        operationName: operationName,
        shouldRetry: shouldRetry,
      );
    } catch (e) {
      if (e is Exception) {
        return await errorHandler.handleError(
          e,
          operationName: operationName,
          fallbackValue: fallbackValue,
        );
      }
      rethrow;
    }
  }
}

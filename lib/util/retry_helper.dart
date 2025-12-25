import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final bool success;
  final int attempts;
  final Duration totalDuration;
  final Object? lastError;
  final StackTrace? lastStackTrace;

  RetryResult({
    this.value,
    required this.success,
    required this.attempts,
    required this.totalDuration,
    this.lastError,
    this.lastStackTrace,
  });

  @override
  String toString() =>
      'RetryResult(success: $success, attempts: $attempts, duration: ${totalDuration.inMilliseconds}ms)';
}

/// Exception thrown when all retry attempts fail
class RetryExhaustedException implements Exception {
  final int attempts;
  final Object lastError;
  final StackTrace? lastStackTrace;

  RetryExhaustedException({
    required this.attempts,
    required this.lastError,
    this.lastStackTrace,
  });

  @override
  String toString() =>
      'RetryExhaustedException: All $attempts attempts failed. Last error: $lastError';
}

/// Configuration for retry behavior
class RetryConfig {
  /// Maximum number of attempts (including the first try)
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Multiplier for exponential backoff (e.g., 2.0 doubles the delay each time)
  final double backoffMultiplier;

  /// Whether to add random jitter to delays (helps prevent thundering herd)
  final bool useJitter;

  /// Function to determine if an error should trigger a retry
  final bool Function(Object error)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
    this.shouldRetry,
  });

  /// Default configuration for API calls
  static const api = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
  );

  /// Configuration for sync operations (more patient)
  static const sync = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 2.0,
  );

  /// Configuration for quick retries
  static const quick = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 2),
    backoffMultiplier: 1.5,
  );
}

/// Helper class for retry operations with exponential backoff
class RetryHelper {
  static final _random = Random();

  /// Execute an operation with retry logic
  ///
  /// [operation] - The async operation to execute
  /// [config] - Retry configuration (defaults to RetryConfig.api)
  /// [onRetry] - Optional callback called before each retry with (attempt, delay, error)
  ///
  /// Returns the result of the operation if successful.
  /// Throws [RetryExhaustedException] if all attempts fail.
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    RetryConfig config = RetryConfig.api,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        // Check if we should retry this error
        if (config.shouldRetry != null && !config.shouldRetry!(e)) {
          debugPrint(
              '⚠️ [Retry] Error not retryable, failing immediately: $e');
          rethrow;
        }

        // Check if we have more attempts
        if (attempt >= config.maxAttempts) {
          debugPrint(
              '❌ [Retry] All $attempt attempts exhausted. Last error: $e');
          throw RetryExhaustedException(
            attempts: attempt,
            lastError: e,
            lastStackTrace: st,
          );
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt, config);

        debugPrint(
            '🔄 [Retry] Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms. Error: $e');

        // Call onRetry callback if provided
        onRetry?.call(attempt, delay, e);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw RetryExhaustedException(
      attempts: config.maxAttempts,
      lastError: lastError ?? 'Unknown error',
      lastStackTrace: lastStackTrace,
    );
  }

  /// Execute an operation with retry logic, returning a result object instead of throwing
  ///
  /// This is useful when you want to handle failures gracefully without exceptions.
  static Future<RetryResult<T>> retryWithResult<T>(
    Future<T> Function() operation, {
    RetryConfig config = RetryConfig.api,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) async {
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        final result = await operation();
        stopwatch.stop();
        return RetryResult(
          value: result,
          success: true,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
        );
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        // Check if we should retry this error
        if (config.shouldRetry != null && !config.shouldRetry!(e)) {
          stopwatch.stop();
          return RetryResult(
            success: false,
            attempts: attempt,
            totalDuration: stopwatch.elapsed,
            lastError: e,
            lastStackTrace: st,
          );
        }

        // Check if we have more attempts
        if (attempt >= config.maxAttempts) {
          stopwatch.stop();
          return RetryResult(
            success: false,
            attempts: attempt,
            totalDuration: stopwatch.elapsed,
            lastError: e,
            lastStackTrace: st,
          );
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt, config);

        // Call onRetry callback if provided
        onRetry?.call(attempt, delay, e);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    stopwatch.stop();
    return RetryResult(
      success: false,
      attempts: config.maxAttempts,
      totalDuration: stopwatch.elapsed,
      lastError: lastError,
      lastStackTrace: lastStackTrace,
    );
  }

  /// Calculate delay for a given attempt using exponential backoff
  static Duration _calculateDelay(int attempt, RetryConfig config) {
    // Calculate base delay with exponential backoff
    final baseDelayMs = config.initialDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    // Cap at max delay
    final cappedDelayMs = min(baseDelayMs.toInt(), config.maxDelay.inMilliseconds);

    // Add jitter if enabled (0-25% random variation)
    if (config.useJitter) {
      final jitter = (_random.nextDouble() * 0.25 * cappedDelayMs).toInt();
      return Duration(milliseconds: cappedDelayMs + jitter);
    }

    return Duration(milliseconds: cappedDelayMs);
  }
}

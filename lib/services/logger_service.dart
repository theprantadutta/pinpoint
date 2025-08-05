import 'dart:developer' as dev;

/// Temporary shim until `flutter pub get` fetches the `logger` package.
/// This keeps the analyzer happy and provides leveled logging immediately.
/// After packages are resolved, we will switch this implementation to use
/// `package:logger/logger.dart` PrettyPrinter with colors/emojis.
class LoggerService {
  LoggerService._internal();

  static final LoggerService _instance = LoggerService._internal();
  static LoggerService get I => _instance;

  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 0, error: error, stackTrace: stackTrace, name: 'VERBOSE');
  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 500, error: error, stackTrace: stackTrace, name: 'DEBUG');
  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 800, error: error, stackTrace: stackTrace, name: 'INFO');
  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 900, error: error, stackTrace: stackTrace, name: 'WARN');
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 1000, error: error, stackTrace: stackTrace, name: 'ERROR');
  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      dev.log('$message',
          level: 1200, error: error, stackTrace: stackTrace, name: 'WTF');

  void success(String message) => i('✅ $message');
  void failure(String message, [dynamic error, StackTrace? stackTrace]) =>
      e('❌ $message', error, stackTrace);

  void json(dynamic data) => d(data);
}

LoggerService get log => LoggerService.I;

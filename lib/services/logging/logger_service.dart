import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Simple and professional Logger for both platforms
class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,          // No extra stack trace info
      errorMethodCount: 2,     // Short error trace
      printTime: false,
      colors: false,           // Removes weird symbols / ANSI colors
      printEmojis: false,
    ),
    level: kDebugMode ? Level.debug : Level.nothing,
  );

  // -----------------------------
  // INFO
  // -----------------------------
  static void info(String message, {String? tag}) =>
      _logger.i(_tag(message, tag));

  // -----------------------------
  // DEBUG
  // -----------------------------
  static void debug(String message, {String? tag}) =>
      _logger.d(_tag(message, tag));

  // -----------------------------
  // WARN
  // -----------------------------
  static void warn(String message, {String? tag}) =>
      _logger.w(_tag(message, tag));

  // -----------------------------
  // ERROR  (🔥 FIXED SIGNATURE)
  // -----------------------------
  static void error(String message,
      {Object? error, StackTrace? stackTrace, String? tag}) {
    _logger.e(
      _tag(message, tag),
      error: error,
      stackTrace: stackTrace,
    );
  }

  // -----------------------------
  // Helper for tagging logs
  // -----------------------------
  static String _tag(String message, String? tag) =>
      tag != null ? "[$tag] $message" : message;
}
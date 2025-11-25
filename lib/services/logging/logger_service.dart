import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Simple and professional Logger for both platforms
class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,          // No extra stack trace info
      errorMethodCount: 2,     // Show only short error stack
      printTime: false,
      colors: false,           // ✅ Remove weird symbols/colors
      printEmojis: false,
    ),
    level: kDebugMode ? Level.debug : Level.nothing,
  );

  static void info(String message, {String? tag}) =>
      _logger.i(_tag(message, tag));

  static void debug(String message, {String? tag}) =>
      _logger.d(_tag(message, tag));

  static void warn(String message, {String? tag}) =>
      _logger.w(_tag(message, tag));

  static void error(String message, Object e, {dynamic error, StackTrace? stackTrace, String? tag}) =>
      _logger.e(_tag(message, tag), error: error, stackTrace: stackTrace);

  static String _tag(String message, String? tag) =>
      tag != null ? "[$tag] $message" : message;
}
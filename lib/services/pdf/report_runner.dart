// lib/services/report_runner.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class ReportRunner {
  static Future<T> run<T>(Future<T> Function() task) {
    return compute(_execute, task);
  }

  static Future<T> _execute<T>(Future<T> Function() task) async {
    return await task();
  }
}
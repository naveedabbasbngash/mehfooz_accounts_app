import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  static const String _fallbackKey = 'fallback_device_id_v1';
  static const MethodChannel _androidChannel = MethodChannel(
    'mehfooz_accounts/device_identity',
  );

  static Future<String> getDeviceId() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final id = await _androidChannel.invokeMethod<String>('getAndroidId');
        if (id != null && id.trim().isNotEmpty) {
          return id.trim();
        }
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        final id = iosInfo.identifierForVendor;
        if (id != null && id.trim().isNotEmpty) {
          return id.trim();
        }
      }
    } catch (_) {
      // Fall through to app-level persistent fallback id.
    }

    return _getOrCreateFallbackId();
  }

  static Future<String> _getOrCreateFallbackId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_fallbackKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final created = _generateFallbackId();
    await prefs.setString(_fallbackKey, created);
    return created;
  }

  static String _generateFallbackId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'fallback-$hex';
  }
}

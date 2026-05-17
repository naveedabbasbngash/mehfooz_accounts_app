// lib/services/local_storage.dart
// ✅ FIXED & HARDENED VERSION (DO NOT SKIP ANYTHING)

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import '../model/user_model.dart';
import 'logging/logger_service.dart';

class LocalStorageService {
  static const String _userListKey = "logged_in_users";
  static const String _lastUsedUserKey = "last_used_user_email";
  static const String _authTokenMapKey = "auth_token_by_email";
  static const String _tenantIdMapKey = "tenant_id_by_email";

  // ============================================================
  // 🔐 SAVE USER (SAFE — NEVER SAVE EMPTY EMAIL)
  // ============================================================
  static Future<void> saveUser(UserModel user) async {
    if (user.email.isEmpty) {
      LoggerService.warn("⛔ Skipped saving user with EMPTY email");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existingList = prefs.getStringList(_userListKey) ?? [];

    existingList.removeWhere((entry) {
      try {
        final decoded = jsonDecode(entry);
        return decoded["email"] == user.email;
      } catch (_) {
        return false;
      }
    });

    existingList.add(jsonEncode(user.toJson()));
    await prefs.setStringList(_userListKey, existingList);

    LoggerService.info("💾 Saved user locally: ${user.email}");
  }

  // ============================================================
  // ✅ SAVE + MARK AS LAST USED (SAFE)
  // ============================================================
  static Future<void> saveOrUpdateUser(UserModel user) async {
    if (user.email.isEmpty) return;
    await saveUser(user);
    await setLastUsedUser(user.email);
  }

  // ============================================================
  // 📥 LOAD ALL USERS (FILTER INVALID)
  // ============================================================
  static Future<List<UserModel>> loadAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_userListKey) ?? [];

    final users = jsonList
        .map((jsonStr) {
          try {
            final map = jsonDecode(jsonStr);
            final user = UserModel.fromJson(map);
            return user.email.isNotEmpty ? user : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<UserModel>()
        .toList();

    LoggerService.info("📥 Loaded users: ${users.length}");
    return users;
  }

  // ============================================================
  // 🕒 SET LAST USED USER (SAFE)
  // ============================================================
  static Future<void> setLastUsedUser(String email) async {
    if (email.isEmpty) {
      LoggerService.warn("⛔ Refused to set EMPTY last used user");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedUserKey, email);
    LoggerService.info("🕒 Set last used user: $email");
  }

  // ============================================================
  // 🔁 LOAD LAST USED USER (GUARANTEED VALID)
  // ============================================================
  static Future<UserModel?> loadLastUsedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_lastUsedUserKey);

    if (email == null || email.isEmpty) {
      LoggerService.warn("⚠ No last used user stored");
      return null;
    }

    final users = await loadAllUsers();

    try {
      final user = users.firstWhere((u) => u.email == email);
      LoggerService.info("✅ Loaded last used user: ${user.email}");
      return user;
    } catch (_) {
      LoggerService.warn("⛔ Last used user not found → clearing");
      await clearLastUsedUser();
      return null;
    }
  }

  // ============================================================
  // 🗑 REMOVE ONE USER
  // ============================================================
  static Future<void> removeUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final existingList = prefs.getStringList(_userListKey) ?? [];

    existingList.removeWhere((entry) {
      try {
        final decoded = jsonDecode(entry);
        return decoded["email"] == email;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_userListKey, existingList);
    await removeAuthToken(email);
    await removeTenantId(email);

    final lastUsed = prefs.getString(_lastUsedUserKey);
    if (lastUsed == email) {
      await prefs.remove(_lastUsedUserKey);
      LoggerService.info("🧹 Removed last used user reference");
    }

    LoggerService.info("🗑 Removed user: $email");
  }

  // ============================================================
  // 🚪 CLEAR LOGIN STATE ONLY (KEEP ACCOUNTS)
  // ============================================================
  static Future<void> clearLoginStateOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUsedUserKey);
    LoggerService.info("🚪 Cleared login state only");
  }

  // ============================================================
  // 🧹 CLEAR LAST USED USER ONLY
  // ============================================================
  static Future<void> clearLastUsedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUsedUserKey);
    LoggerService.info("🧹 Cleared last used user");
  }

  // ============================================================
  // 🔐 AUTH TOKEN STORAGE (PER EMAIL)
  // ============================================================
  static Future<void> saveAuthToken({
    required String email,
    required String token,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedToken = token.trim();

    if (normalizedEmail.isEmpty || normalizedToken.isEmpty) {
      LoggerService.warn("⛔ Refused to save auth token (empty email/token)");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authTokenMapKey);
    final Map<String, dynamic> map = () {
      if (raw == null || raw.trim().isEmpty) {
        return <String, dynamic>{};
      }
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }();

    map[normalizedEmail] = normalizedToken;
    await prefs.setString(_authTokenMapKey, jsonEncode(map));
    LoggerService.info("🔐 Saved auth token for $normalizedEmail");
  }

  static Future<String?> loadAuthToken(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authTokenMapKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final token = map[normalizedEmail]?.toString().trim();
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadAuthTokenForLastUsedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_lastUsedUserKey)?.trim() ?? '';
    if (email.isEmpty) return null;
    return loadAuthToken(email);
  }

  static Future<void> removeAuthToken(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authTokenMapKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.remove(normalizedEmail);
      await prefs.setString(_authTokenMapKey, jsonEncode(map));
      LoggerService.info("🗑 Removed auth token for $normalizedEmail");
    } catch (_) {
      // no-op
    }
  }

  static Future<void> saveTenantId({
    required String email,
    required int tenantId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || tenantId <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tenantIdMapKey);
    final Map<String, dynamic> map = () {
      if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }();

    map[normalizedEmail] = tenantId;
    await prefs.setString(_tenantIdMapKey, jsonEncode(map));
    LoggerService.info("🏢 Saved tenant id for $normalizedEmail -> $tenantId");
  }

  static Future<int?> loadTenantId(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tenantIdMapKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final value = map[normalizedEmail];
      final id = int.tryParse(value?.toString() ?? '');
      if (id == null || id <= 0) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  static Future<int?> loadTenantIdForLastUsedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_lastUsedUserKey)?.trim() ?? '';
    if (email.isEmpty) return null;
    return loadTenantId(email);
  }

  static Future<void> removeTenantId(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tenantIdMapKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.remove(normalizedEmail);
      await prefs.setString(_tenantIdMapKey, jsonEncode(map));
    } catch (_) {
      // no-op
    }
  }

  // ============================================================
  // ❌ FULL RESET (DEBUG / LOGOUT ALL)
  // ============================================================
  static Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userListKey);
    await prefs.remove(_lastUsedUserKey);
    await prefs.remove(_authTokenMapKey);
    await prefs.remove(_tenantIdMapKey);
    LoggerService.info("🧹 All local users cleared");
  }
}

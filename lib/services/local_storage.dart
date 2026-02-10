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
  // ❌ FULL RESET (DEBUG / LOGOUT ALL)
  // ============================================================
  static Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userListKey);
    await prefs.remove(_lastUsedUserKey);
    LoggerService.info("🧹 All local users cleared");
  }
}
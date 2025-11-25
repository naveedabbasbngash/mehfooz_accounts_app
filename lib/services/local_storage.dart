// Place this file in: lib/services/local_storage.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

import '../model/user_model.dart';
import 'logging/logger_service.dart';

class LocalStorageService {
  static const String _userListKey = "logged_in_users";

  /// ✅ Save or update a user in local storage
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final existingList = prefs.getStringList(_userListKey) ?? [];

    // 🔄 Remove any previous instance of the user by email
    existingList.removeWhere((entry) {
      final decoded = jsonDecode(entry);
      return decoded["email"] == user.email;
    });

    // ➕ Add the new/updated user
    existingList.add(jsonEncode(user.toJson()));

    // 💾 Persist list
    await prefs.setStringList(_userListKey, existingList);
    LoggerService.info("💾 Saved user locally: ${user.email}");
  }

  /// 📦 Load all saved users from storage
  static Future<List<UserModel>> loadAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_userListKey) ?? [];

    final users = jsonList.map((jsonStr) {
      try {
        final map = jsonDecode(jsonStr);
        return UserModel.fromJson(map);
      } catch (e, s) {
        return null;
      }
    }).whereType<UserModel>().toList();

    LoggerService.info("📥 Loaded users: ${users.length}");
    return users;
  }

  /// 👤 Load the most recent logged-in user (last saved)
  static Future<UserModel?> loadLatestUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_userListKey);

    if (jsonList == null || jsonList.isEmpty) {
      LoggerService.warn("⚠ No users found in local storage.");
      return null;
    }

    try {
      final latestJson = jsonDecode(jsonList.last);
      final latestUser = UserModel.fromJson(latestJson);
      LoggerService.info("✅ Loaded latest user: ${latestUser.email}");
      return latestUser;
    } catch (e, s) {
      return null;
    }
  }

  /// 🧹 Clear all stored users
  static Future<void> clearAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userListKey);
    LoggerService.info("🧹 All local users cleared.");
  }

  /// ❌ Remove a specific user by email
  static Future<void> removeUserByEmail(String email) async {
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
    LoggerService.info("🗑 Removed user: $email");
  }
}
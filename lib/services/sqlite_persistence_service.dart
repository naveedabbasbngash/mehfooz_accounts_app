// Place this file in: lib/services/sqlite_persistence_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SqlitePersistenceService {
  static final Logger log = Logger();
  static const String _dbPathKey = "active_sqlite_db_path";

  /// 🔐 Save verified path after validation
  static Future<void> saveActiveDbPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbPathKey, path);
    log.i("✅ Active DB path saved: $path");
  }

  /// 📂 Retrieve saved DB path on startup
  static Future<String?> getActiveDbPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_dbPathKey);
    log.i("📦 Retrieved active DB path: $path");
    return path;
  }

  /// ❌ Clear active DB path (e.g., on logout or reset)
  static Future<void> clearDbPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dbPathKey);
    log.w("⚠️ Active DB path cleared.");
  }
}
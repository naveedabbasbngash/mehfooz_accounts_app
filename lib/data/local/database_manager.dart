// lib/data/local/database_manager.dart

import 'dart:io';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

import 'app_database.dart';

/// ======================================================================
/// DATABASE MANAGER — SINGLETON
///  ✔ Copies imported DB into app documents directory
///  ✔ Activates Drift on that internal copy
///  ✔ Can be restored on next app launch
///  ✔ Used by HomeViewModel and repositories
/// ======================================================================
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  static AppDatabase? _database;

  final Logger _log = Logger();

  DatabaseManager._internal();

  static DatabaseManager get instance => _instance;

  /// Permanently saved internal DB filename
  static const String _savedDbFileName = "mahfooz_imported.sqlite";

  /// Cached active internal path (for debugging / UI if needed)
  String? activeDbPath;

  /// ===================================================================
  ///  GET CURRENT DB (throws if not loaded)
  /// ===================================================================
  AppDatabase get db {
    if (_database == null) {
      throw Exception("❌ AppDatabase not loaded. Import or restore first.");
    }
    return _database!;
  }

  /// ===================================================================
  ///  INTERNAL PATH WHERE DB IS STORED
  /// ===================================================================
  Future<String> _getInternalDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _savedDbFileName);
  }

  /// ===================================================================
  ///  COPY IMPORTED SQLITE → INTERNAL APP DIRECTORY
  /// ===================================================================
  Future<String> _copyToInternal(String importedPath) async {
    final importedFile = File(importedPath);

    if (!await importedFile.exists()) {
      throw Exception("❌ Imported file does not exist: $importedPath");
    }

    final internalPath = await _getInternalDbPath();
    final internalFile = File(internalPath);

    // Replace previous DB safely
    if (await internalFile.exists()) {
      await internalFile.delete();
    }

    await importedFile.copy(internalPath);

    _log.i("📦 Copied imported DB to internal path:\n$internalPath");

    activeDbPath = internalPath;
    return internalPath;
  }

  /// ===================================================================
  ///  ACTIVATE DRIFT DB FROM A SQLITE FILE (already inside app folder)
  /// ===================================================================
  Future<void> _activateFromPath(String sqlitePath) async {
    final file = File(sqlitePath);
    if (!file.existsSync()) {
      _log.e("❌ Cannot activate — file does not exist: $sqlitePath");
      throw Exception("Database file missing: $sqlitePath");
    }

    _log.i("🛠 Activating Drift DB from: $sqlitePath");

    // Close old DB if any
    await _database?.close();

    final executor = NativeDatabase(
      file,
      logStatements: false, // set true only when debugging queries
    );

    _database = AppDatabase(executor);
    activeDbPath = sqlitePath;

    _log.i("✅ Drift DB activated successfully.");
  }

  /// ===================================================================
  ///  PUBLIC METHOD — used by HomeViewModel.importDatabase()
  ///  Copies importedPath → internal file → activates
  /// ===================================================================
  Future<void> useImportedDb(String importedPath) async {
    final internalPath = await _copyToInternal(importedPath);
    await _activateFromPath(internalPath);
  }

  /// ===================================================================
  ///  PUBLIC METHOD — used by HomeViewModel.importDatabase()
  ///  Import + Activate + run callback (load pending, etc.)
  /// ===================================================================
  Future<void> activateAndThen(
      String importedPath,
      Future<void> Function(AppDatabase db) callback,
      ) async {
    await useImportedDb(importedPath);
    _log.i("🚀 Running post-activation tasks...");
    await callback(db);
  }

  /// ===================================================================
  ///  RESTORE DB ON APP LAUNCH
  ///  - Called if you want to restore using the internal file directly.
  ///  - HomeViewModel currently restores via SharedPreferences + useImportedDb.
  ///  - Still useful as a fallback utility.
  /// ===================================================================
  Future<bool> restoreDatabaseIfExists() async {
    final internalPath = await _getInternalDbPath();
    final file = File(internalPath);

    if (!file.existsSync()) {
      _log.w("⚠ No existing DB in app directory at: $internalPath");
      return false;
    }

    _log.i("📦 Found existing DB → Restoring: $internalPath");

    try {
      await _activateFromPath(internalPath);
      return true;
    } catch (e, st) {
      _log.e("❌ Failed to restore previous DB", error: e, stackTrace: st);
      return false;
    }
  }

  /// ===================================================================
  ///  LOGOUT / RESET
  /// ===================================================================
  Future<void> clear() async {
    await _database?.close();
    _database = null;

    final path = await _getInternalDbPath();
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
      _log.w("🗑 Deleted stored DB file: $path");
    }

    activeDbPath = null;
    _log.w("⚠️ DatabaseManager cleared.");
  }
}
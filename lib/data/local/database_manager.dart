// lib/data/local/database_manager.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

import 'app_database.dart';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  static AppDatabase? _database;

  final Logger _log = Logger();

  DatabaseManager._internal();

  static DatabaseManager get instance => _instance;

  static const String _savedDbFileName = "mahfooz_imported.sqlite";

  String? activeDbPath;

  AppDatabase get db {
    if (_database == null) {
      throw Exception("❌ AppDatabase not loaded. Import or restore first.");
    }
    return _database!;
  }

  Future<String> _getInternalDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _savedDbFileName);
  }

  Future<String> _copyToInternal(String importedPath) async {
    final importedFile = File(importedPath);

    if (!await importedFile.exists()) {
      throw Exception("❌ Imported file does not exist: $importedPath");
    }

    final internalPath = await _getInternalDbPath();
    final internalFile = File(internalPath);

    if (await internalFile.exists()) {
      await internalFile.delete();
    }

    await importedFile.copy(internalPath);

    _log.i("📦 Copied imported DB → $internalPath");

    activeDbPath = internalPath;
    return internalPath;
  }

  // --------------------------------------------------------------------------
  // 🛠 AUTO MIGRATION FUNCTIONS
  // --------------------------------------------------------------------------

  Future<void> _ensureColumnExists(
      DatabaseConnectionUser exec,
      String table,
      String column,
      String definition,
      ) async {
    final res = await exec.customSelect(
      "PRAGMA table_info('$table');",
    ).get();

    final columns = res.map((row) => row.data['name'] as String).toList();

    if (!columns.contains(column)) {
      await exec.customStatement(
        "ALTER TABLE $table ADD COLUMN $column $definition;",
      );
      _log.i("🧩 Added missing column $column to $table");
    }
  }

  /// 🔧 Run auto-migration using an *existing* AppDatabase
  Future<void> _runAutoMigration(AppDatabase db) async {
    _log.i("🔧 Running AUTO-MIGRATION checks...");

    // --------------------------
    // Acc_Personal Fixes
    // --------------------------
    await _ensureColumnExists(db, "Acc_Personal", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "Acc_Personal", "UpdatedAt", "TEXT");
    await _ensureColumnExists(db, "Acc_Personal", "IsDeleted", "INTEGER DEFAULT 0");

    // --------------------------
    // AccType Fixes
    // --------------------------
    await _ensureColumnExists(db, "AccType", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "AccType", "UpdatedAt", "TEXT");

    // --------------------------
    // Transactions_P Fixes
    // --------------------------
    await _ensureColumnExists(db, "Transactions_P", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "Transactions_P", "UpdatedAt", "TEXT");
    await _ensureColumnExists(db, "Transactions_P", "IsDeleted", "INTEGER DEFAULT 0");

    _log.i("✅ Auto-migration completed successfully.");
  }

  // --------------------------------------------------------------------------
  // ACTIVATE DB
  // --------------------------------------------------------------------------
  Future<void> _activateFromPath(String sqlitePath) async {
    final file = File(sqlitePath);
    if (!file.existsSync()) {
      _log.e("❌ Missing database file: $sqlitePath");
      throw Exception("Database file missing: $sqlitePath");
    }

    _log.i("🛠 Activating Drift DB from: $sqlitePath");

    // Close old DB (if any)
    await _database?.close();
    _database = null;

    // Create executor for this file
    final executor = NativeDatabase(
      file,
      logStatements: false,
    );

    // ✅ Create ONE AppDatabase for this executor
    final appDb = AppDatabase(executor);

    // 🧠 Run auto-migration on the same instance
    await _runAutoMigration(appDb);

    // Now assign as the active DB
    _database = appDb;
    activeDbPath = sqlitePath;

    _log.i("✅ Drift DB activated successfully.");
  }

  Future<void> useImportedDb(String importedPath) async {
    final internalPath = await _copyToInternal(importedPath);
    await _activateFromPath(internalPath);
  }

  Future<void> activateAndThen(
      String importedPath,
      Future<void> Function(AppDatabase db) callback,
      ) async {
    await useImportedDb(importedPath);
    _log.i("🚀 Running post-activation tasks...");
    await callback(db);
  }

  Future<bool> restoreDatabaseIfExists() async {
    final internalPath = await _getInternalDbPath();
    final file = File(internalPath);

    if (!file.existsSync()) {
      _log.w("⚠ No stored DB found at: $internalPath");
      return false;
    }

    _log.i("📦 Restoring existing DB: $internalPath");

    try {
      await _activateFromPath(internalPath);
      return true;
    } catch (e, st) {
      _log.e("❌ Failed to restore DB", error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> clear() async {
    await _database?.close();
    _database = null;

    final path = await _getInternalDbPath();
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
      _log.w("🗑 Deleted DB file at: $path");
    }

    activeDbPath = null;
    _log.w("⚠️ DatabaseManager cleared.");
  }
}
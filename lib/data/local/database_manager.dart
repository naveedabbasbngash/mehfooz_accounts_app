// lib/data/local/database_manager.dart

import 'dart:io';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

import 'app_database.dart';

class DatabaseManager {
  DatabaseManager._internal();
  static final DatabaseManager _instance = DatabaseManager._internal();
  static DatabaseManager get instance => _instance;

  final Logger _log = Logger();

  static AppDatabase? _database;

  String? activeDbPath;
  String? activeUserEmail;

  AppDatabase get db {
    if (_database == null) {
      throw Exception("❌ AppDatabase not loaded.");
    }
    return _database!;
  }

  // =====================================================================
  // HARD RESET
  // =====================================================================
  Future<void> reset() async {
    _log.w("🧹 DatabaseManager.reset() called");

    if (_database != null) {
      try {
        await _database!.close();
        _log.i("🔌 Closed active Drift DB");
      } catch (e) {
        _log.w("⚠ Failed to close DB: $e");
      }
    }

    _database = null;
    activeDbPath = null;
    activeUserEmail = null;

    _log.i("✅ DatabaseManager reset completed");
  }

  // =====================================================================
  // Helper: Safe email → filename
  // =====================================================================
  Future<String> _getUserDbPath(String email) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeEmail = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final folder = p.join(dir.path, "mahfooz_users");
    return p.join(folder, "db_$safeEmail.sqlite");
  }

  Future<void> _ensureUserFolder() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, "mahfooz_users"));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
      _log.i("📁 Created DB folder: ${folder.path}");
    }
  }

  // =====================================================================
  // ✅ NEW: Ensure base tables exist (EMPTY DB SUPPORT)
  // =====================================================================
  Future<void> _ensureBaseSchema(AppDatabase db) async {
    // These are safe to run repeatedly.
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Acc_Personal (
        AccID INTEGER PRIMARY KEY,
        RDate TEXT,
        Name TEXT,
        Phone TEXT,
        Fax TEXT,
        Address TEXT,
        Description TEXT,
        UAccName TEXT,
        statusg TEXT,
        UserID INTEGER,
        CompanyID INTEGER,
        WName TEXT,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT,
        IsDeleted INTEGER DEFAULT 0
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS AccType (
        AccTypeID INTEGER PRIMARY KEY,
        AccTypeName TEXT,
        AccTypeNameu TEXT,
        FLAG TEXT,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Company (
        CompanyID INTEGER PRIMARY KEY,
        CompanyName TEXT,
        Remarks TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Db_Info (
        email_address TEXT,
        database_name TEXT
      );
    ''');

    // You said now: VoucherNo is primary.
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Transactions_P (
        VoucherNo REAL PRIMARY KEY,
        TDate TEXT,
        AccID INTEGER,
        AccTypeID INTEGER,
        Description TEXT,
        Dr REAL,
        Cr REAL,
        Status TEXT,
        st TEXT,
        updatestatus TEXT,
        currencystatus TEXT,
        cashstatus TEXT,
        UserID INTEGER,
        CompanyID INTEGER,
        WName TEXT,
        msgno TEXT,
        hwls1 TEXT,
        hwls TEXT,
        advancemess TEXT,
        cbal INTEGER,
        cbal1 INTEGER,
        TTIME TEXT,
        PD TEXT,
        msgno2 TEXT,
        OTHERS TEXT,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT,
        IsDeleted INTEGER DEFAULT 0
      );
    ''');

    _log.i("✅ Base schema ensured (tables exist).");
  }

  // =====================================================================
  // AUTO MIGRATION (columns)
  // =====================================================================
  Future<void> _ensureColumnExists(
      AppDatabase db,
      String table,
      String column,
      String definition,
      ) async {
    final res = await db.customSelect(
      "PRAGMA table_info('$table');",
    ).get();

    final columns = res.map((row) => row.data['name'] as String).toList();

    if (!columns.contains(column)) {
      await db.customStatement(
        "ALTER TABLE $table ADD COLUMN $column $definition;",
      );
      _log.i("🧩 Added $column to $table");
    }
  }

  Future<void> _runAutoMigration(AppDatabase db) async {
    _log.i("🔧 Running auto-migration...");

    await _ensureColumnExists(db, "Acc_Personal", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "Acc_Personal", "UpdatedAt", "TEXT");
    await _ensureColumnExists(db, "Acc_Personal", "IsDeleted", "INTEGER DEFAULT 0");

    await _ensureColumnExists(db, "AccType", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "AccType", "UpdatedAt", "TEXT");

    await _ensureColumnExists(db, "Transactions_P", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "Transactions_P", "UpdatedAt", "TEXT");
    await _ensureColumnExists(db, "Transactions_P", "IsDeleted", "INTEGER DEFAULT 0");

    _log.i("✅ Auto-migration done.");
  }

  // =====================================================================
  // INTERNAL: Activate DB by path
  // =====================================================================
  Future<void> _activateFromPath(String sqlitePath, {String? email}) async {
    final file = File(sqlitePath);

    if (!file.existsSync()) {
      throw Exception("❌ DB file does not exist: $sqlitePath");
    }

    _log.i("🛠 Activating DB: $sqlitePath for user: ${email ?? activeUserEmail}");

    // ✅ If a DB is open, close it here (extra safety)
    if (_database != null) {
      _log.w("🔁 Reopening Drift DB (closing old connection first)");
      try {
        await _database!.close();
      } catch (e) {
        _log.w("⚠ Failed to close old DB: $e");
      }
      _database = null;
    }

    final executor = NativeDatabase(file, logStatements: false);
    final appDb = AppDatabase(executor);

    // ✅ Only for empty DB support (ok to keep)
    await _ensureBaseSchema(appDb);
    await _runAutoMigration(appDb);

    _database = appDb;
    activeDbPath = sqlitePath;
    activeUserEmail = email ?? activeUserEmail;

    _log.i("✅ Activated DB: $sqlitePath");
  }

  // =====================================================================
  // COPY IMPORTED DB → PER-USER FILE → ACTIVATE
  // =====================================================================
  Future<void> useImportedDbForUser(String importedPath, String email) async {
    await _ensureUserFolder();

    final importedFile = File(importedPath);
    if (!await importedFile.exists()) {
      _log.e("❌ useImportedDbForUser: Source missing: $importedPath");
      return;
    }

    final userDbPath = await _getUserDbPath(email);
    final userFile = File(userDbPath);

    if (await userFile.exists()) {
      await userFile.delete();
      _log.w("♻ Old DB deleted for user: $email");
    }

    await importedFile.copy(userDbPath);
    _log.i("📦 User DB stored → $userDbPath");

    // ✅ CRITICAL: Always close & reopen Drift after file replacement
    await reset();
    await _activateFromPath(userDbPath, email: email);

    // ✅ DEBUG: confirm Db_Info after activation
    try {
      final info = await db.select(db.dbInfoTable).get();
      _log.i("🧪 Db_Info after import activation → "
          "rows=${info.length}, email=${info.isNotEmpty ? info.first.emailAddress : 'EMPTY'}");
    } catch (e) {
      _log.e("❌ Failed reading Db_Info after activation", error: e);
    }
  }
  // =====================================================================
  // ✅ RESTORE OR CREATE EMPTY (Decision A)
  // =====================================================================
  Future<bool> restoreDatabaseForUser(String email) async {
    await _ensureUserFolder();

    final userDbPath = await _getUserDbPath(email);
    final file = File(userDbPath);

    activeUserEmail = email;

    if (!file.existsSync()) {
      _log.w("⚠ No DB stored for user: $email → creating empty DB now");

      // create empty file
      await file.create(recursive: true);

      // activate it (this will create tables)
      await _activateFromPath(userDbPath, email: email);

      return true; // ✅ DB is now available
    }

    _log.i("📂 Restoring DB for user: $email → $userDbPath");
    await _activateFromPath(userDbPath, email: email);
    return true;
  }

  // =====================================================================
  Future<void> clearUserDb(String email) async {
    final path = await _getUserDbPath(email);
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
      _log.w("🗑 Deleted DB for: $email");
    }

    if (activeUserEmail == email) {
      await reset();
      _log.w("🔌 Closed active DB after deleting user DB");
    }
  }

  Future<AppDatabase> previewDatabase(String path) async {
    final file = File(path);

    if (!file.existsSync()) {
      throw Exception("❌ previewDatabase: File not found → $path");
    }

    final executor = NativeDatabase(file, logStatements: false);
    return AppDatabase(executor);
  }

  Future<bool> userDatabaseExists(String email) async {
    final path = await _getUserDbPath(email);
    return File(path).existsSync();
  }
}
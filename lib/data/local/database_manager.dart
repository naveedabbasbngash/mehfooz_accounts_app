// lib/data/local/database_manager.dart

import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/services.dart';
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
  static const String _firstRunSeedAsset = 'assets/seed/first_run_seed.json';
  static const String _migrationsTable = '_AppMigrations';
  static const String _cashHeadMigrationKey = '2026_03_cash_head_by_name';
  static const String defaultCompanyName = 'Mahfooz Accounts';

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
        SMS INTEGER DEFAULT 0,
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
        IsDeleted INTEGER DEFAULT 0,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Company (
        CompanyID INTEGER PRIMARY KEY AUTOINCREMENT,
        CompanyName TEXT,
        Remarks TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Accounts_Heads (
        acc_head_id INTEGER PRIMARY KEY,
        acc_head_name TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Db_Info (
        email_address TEXT,
        database_name TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Account_PCurrencyAssignment (
        RegID INTEGER PRIMARY KEY,
        AccID INTEGER,
        AccountTypeID INTEGER,
        CompanyID INTEGER,
        IsDeleted INTEGER DEFAULT 0,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS AccountCurrencyMap (
        AccID INTEGER NOT NULL,
        AccTypeID INTEGER NOT NULL,
        CompanyID INTEGER NOT NULL,
        IsEnabled INTEGER DEFAULT 1,
        UpdatedAt TEXT,
        PRIMARY KEY (AccID, AccTypeID, CompanyID)
      );
    ''');

    // You said now: VoucherNo is primary.
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Transactions_P (
        VoucherNo INTEGER PRIMARY KEY,
        TxGuid TEXT,
        TDate TEXT,
        AccID INTEGER,
        AccTypeID INTEGER,
        Description TEXT,
        Quality TEXT,
        Rate REAL,
        Weight REAL,
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

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS tblCashTrans (
        VoucherNo INTEGER PRIMARY KEY,
        TDate TEXT,
        AccTypeID INTEGER,
        Description TEXT,
        fcamount REAL,
        lcamount REAL,
        transtype TEXT,
        exchangerate REAL,
        AccTypeID1 INTEGER,
        statuss TEXT,
        statuss1 TEXT,
        fcdr REAL,
        fccr REAL,
        lcdr REAL,
        lccr REAL,
        stc TEXT,
        CompanyID INTEGER,
        IsSynced INTEGER DEFAULT 0,
        UpdatedAt TEXT,
        IsDeleted INTEGER DEFAULT 0
      );
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS Sheet1 (
        AccID INTEGER PRIMARY KEY,
        RDate TEXT,
        Name TEXT,
        IsDeleted INTEGER DEFAULT 0,
        CreatedDate TEXT,
        RowGUID TEXT,
        SyncStatus TEXT
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
    final res = await db.customSelect("PRAGMA table_info('$table');").get();

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

    await _ensureColumnExists(
      db,
      "Acc_Personal",
      "IsSynced",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(db, "Acc_Personal", "UpdatedAt", "TEXT");
    await _ensureColumnExists(
      db,
      "Acc_Personal",
      "IsDeleted",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(db, "Acc_Personal", "SMS", "INTEGER DEFAULT 0");

    await _ensureColumnExists(db, "AccType", "IsDeleted", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "AccType", "IsSynced", "INTEGER DEFAULT 0");
    await _ensureColumnExists(db, "AccType", "UpdatedAt", "TEXT");

    await _ensureColumnExists(
      db,
      "Account_PCurrencyAssignment",
      "CompanyID",
      "INTEGER",
    );
    await _ensureColumnExists(
      db,
      "Account_PCurrencyAssignment",
      "IsDeleted",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(
      db,
      "Account_PCurrencyAssignment",
      "IsSynced",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(
      db,
      "Account_PCurrencyAssignment",
      "UpdatedAt",
      "TEXT",
    );

    await _ensureColumnExists(
      db,
      "Transactions_P",
      "IsSynced",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(db, "Transactions_P", "TxGuid", "TEXT");
    await _ensureColumnExists(db, "Transactions_P", "UpdatedAt", "TEXT");
    await _ensureColumnExists(
      db,
      "Transactions_P",
      "IsDeleted",
      "INTEGER DEFAULT 0",
    );
    await _ensureColumnExists(db, "Transactions_P", "Quality", "TEXT");
    await _ensureColumnExists(db, "Transactions_P", "Rate", "REAL");
    await _ensureColumnExists(db, "Transactions_P", "Weight", "REAL");

    // Ledger/report performance index (safe, idempotent)
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_transactions_main
      ON Transactions_P (CompanyID, AccID, AccTypeID, TDate, VoucherNo);
    ''');

    // Deterministic GUID for legacy rows so backend can derive the same key.
    await db.customStatement('''
      UPDATE Transactions_P
      SET TxGuid = 'legacy-'
        || COALESCE(CAST(CompanyID AS TEXT), '0')
        || '-'
        || REPLACE(COALESCE(CAST(VoucherNo AS TEXT), ''), '.0', '')
      WHERE COALESCE(TRIM(TxGuid), '') = ''
    ''');

    await db.customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_txguid_unique
      ON Transactions_P (TxGuid);
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_account_currency_company_acc
      ON AccountCurrencyMap (CompanyID, AccID);
    ''');

    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_assignment_sync_state
      ON Account_PCurrencyAssignment (IsSynced, AccID, AccountTypeID);
    ''');

    await _migrateCashHeadsFromAccountNameIfNeeded(db);

    _log.i("✅ Auto-migration done.");
  }

  Future<void> _ensureMigrationsTable(AppDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS $_migrationsTable (
        migration_key TEXT PRIMARY KEY,
        applied_at TEXT NOT NULL
      );
    ''');
  }

  Future<bool> _isMigrationApplied(AppDatabase db, String key) async {
    await _ensureMigrationsTable(db);
    final rows = await db
        .customSelect(
          '''
          SELECT 1
          FROM $_migrationsTable
          WHERE migration_key = ?1
          LIMIT 1
          ''',
          variables: [Variable.withString(key)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _markMigrationApplied(AppDatabase db, String key) async {
    await _ensureMigrationsTable(db);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''
      INSERT OR REPLACE INTO $_migrationsTable (migration_key, applied_at)
      VALUES (?1, ?2)
      ''',
      [key, nowIso],
    );
  }

  Future<void> _migrateCashHeadsFromAccountNameIfNeeded(AppDatabase db) async {
    if (await _isMigrationApplied(db, _cashHeadMigrationKey)) return;

    final totalRows = await _countRows(db, "Acc_Personal");

    final pendingRow = await db.customSelect('''
          SELECT COUNT(1) AS c
          FROM Acc_Personal
          WHERE COALESCE(IsDeleted, 0) = 0
            AND LOWER(TRIM(COALESCE(Name, ''))) LIKE '%cash%'
            AND UPPER(TRIM(COALESCE(statusg, ''))) <> 'CASH'
          ''').getSingle();
    final pending = _asInt(pendingRow.data['c']);

    if (pending > 0) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.customStatement(
        '''
        UPDATE Acc_Personal
        SET statusg = 'CASH',
            IsSynced = 0,
            UpdatedAt = ?1
        WHERE COALESCE(IsDeleted, 0) = 0
          AND LOWER(TRIM(COALESCE(Name, ''))) LIKE '%cash%'
          AND UPPER(TRIM(COALESCE(statusg, ''))) <> 'CASH'
        ''',
        [nowIso],
      );
      _log.i("✅ Cash-head migration updated $pending account(s).");
      await _markMigrationApplied(db, _cashHeadMigrationKey);
      return;
    }

    // If table is empty (brand-new DB before seed), skip marking so it can run later.
    if (totalRows <= 0) {
      _log.i(
        "ℹ️ Cash-head migration deferred (Acc_Personal is empty at this stage).",
      );
      return;
    }

    await _markMigrationApplied(db, _cashHeadMigrationKey);
    _log.i("ℹ️ Cash-head migration checked: no rows needed updates.");
  }

  Future<int> _countRows(AppDatabase db, String tableName) async {
    final row = await db
        .customSelect('SELECT COUNT(1) AS c FROM $tableName;')
        .getSingle();
    final value = row.data['c'];
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isNullish(dynamic value) {
    if (value == null) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isEmpty || normalized == 'null';
    }
    return false;
  }

  Object? _seedValue(dynamic value) {
    if (_isNullish(value)) return null;
    if (value is bool) return value ? 1 : 0;
    if (value == null || value is num || value is String) return value;
    return value.toString();
  }

  Future<void> _insertSeedRows(
    AppDatabase db,
    String tableName,
    dynamic rowsRaw,
    String? requiredPrimaryKey, {
    bool replaceExisting = false,
  }) async {
    if (rowsRaw is! List) return;
    for (final item in rowsRaw) {
      if (item is! Map) continue;

      final row = Map<String, dynamic>.from(item.cast<String, dynamic>());

      // Excel uses Wname, app schema uses WName.
      if (tableName == "Transactions_P" &&
          row.containsKey('Wname') &&
          !row.containsKey('WName')) {
        row['WName'] = row.remove('Wname');
      }

      if (requiredPrimaryKey != null) {
        final pkValue = row[requiredPrimaryKey];
        if (_isNullish(pkValue)) {
          _log.w(
            "⚠️ Skipping seed row in $tableName: missing $requiredPrimaryKey",
          );
          continue;
        }
      }

      final hasAnyValue = row.values.any((v) => !_isNullish(v));
      if (!hasAnyValue) {
        _log.w("⚠️ Skipping empty seed row in $tableName");
        continue;
      }

      final columns = row.keys.where((k) => k.trim().isNotEmpty).toList();
      if (columns.isEmpty) continue;

      final placeholders = List.filled(columns.length, '?').join(', ');
      final conflict = replaceExisting ? 'REPLACE' : 'IGNORE';
      final sql =
          'INSERT OR $conflict INTO $tableName (${columns.join(', ')}) VALUES ($placeholders);';
      final values = columns.map((c) => _seedValue(row[c])).toList();

      await db.customStatement(sql, values);
    }
  }

  List<Map<String, dynamic>> _filteredAccPersonalRows(dynamic rowsRaw) {
    if (rowsRaw is! List) return const [];

    final result = <Map<String, dynamic>>[];
    for (final item in rowsRaw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item.cast<String, dynamic>());

      final idValue = row['AccID'];
      final id = int.tryParse((idValue ?? '').toString().trim());
      if (id == 1008 || id == 1009) {
        _log.i("ℹ️ Skipping Acc_Personal seed row with AccID=$id");
        continue;
      }

      result.add(row);
    }
    return result;
  }

  Future<void> _ensureAccountHeadsFromAccPersonal(AppDatabase db) async {
    final existingRows = await db.customSelect('''
          SELECT acc_head_id, acc_head_name
          FROM Accounts_Heads
          ''').get();

    final existingNames = <String>{};
    var nextId = 1;

    for (final row in existingRows) {
      final id = _asInt(row.data['acc_head_id']);
      if (id >= nextId) nextId = id + 1;
      final name = (row.data['acc_head_name'] ?? '').toString().trim();
      if (name.isNotEmpty) existingNames.add(name.toLowerCase());
    }

    final statusRows = await db.customSelect('''
          SELECT DISTINCT TRIM(COALESCE(statusg, '')) AS head_name
          FROM Acc_Personal
          WHERE TRIM(COALESCE(statusg, '')) <> ''
            AND COALESCE(IsDeleted, 0) = 0
          ORDER BY head_name COLLATE NOCASE ASC
          ''').get();

    var inserted = 0;
    for (final row in statusRows) {
      final name = (row.data['head_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (existingNames.contains(normalized)) continue;

      await db.customStatement(
        '''
        INSERT INTO Accounts_Heads (acc_head_id, acc_head_name)
        VALUES (?1, ?2)
        ''',
        [nextId, name],
      );
      existingNames.add(normalized);
      nextId += 1;
      inserted += 1;
    }

    if (inserted > 0) {
      _log.i("✅ Synced $inserted account head(s) from Acc_Personal.statusg");
    }
  }

  Future<void> _seedFromBundledAssetIfNeeded(AppDatabase db) async {
    final accTypeBefore = await _countRows(db, "AccType");
    final accPersonalBefore = await _countRows(db, "Acc_Personal");

    final raw = await rootBundle.loadString(_firstRunSeedAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      _log.w("⚠️ Seed asset format invalid. Skipping first-run seed.");
      return;
    }

    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      _log.w("⚠️ Seed asset has no tables section. Skipping first-run seed.");
      return;
    }

    await db.transaction(() async {
      await _insertSeedRows(db, "AccType", tables['AccType'], "AccTypeID");

      await _insertSeedRows(
        db,
        "Acc_Personal",
        _filteredAccPersonalRows(tables['Acc_Personal']),
        "AccID",
      );
    });

    final accTypeAfter = await _countRows(db, "AccType");
    final accPersonalAfter = await _countRows(db, "Acc_Personal");
    final addedAccType = accTypeAfter - accTypeBefore;
    final addedAccPersonal = accPersonalAfter - accPersonalBefore;

    if (addedAccType > 0 || addedAccPersonal > 0) {
      _log.i(
        "✅ Seed sync done: +$addedAccType AccType, +$addedAccPersonal Acc_Personal",
      );
    } else {
      _log.i("ℹ️ Seed sync checked: no missing AccType/Acc_Personal rows.");
    }

    // Run data migration again after seed; this catches first-run rows too.
    await _migrateCashHeadsFromAccountNameIfNeeded(db);
    await _ensureAccountHeadsFromAccPersonal(db);
    await _ensureAccountCurrencyAssignments(db);
  }

  Future<int> _ensureDefaultCompanyExists(AppDatabase db) async {
    final existing = await db
        .customSelect(
          'SELECT CompanyID FROM Company ORDER BY CompanyID LIMIT 1;',
        )
        .get();

    if (existing.isNotEmpty) {
      return _asInt(existing.first.data['CompanyID']);
    }

    await db.customStatement(
      'INSERT INTO Company (CompanyName, Remarks) VALUES (?1, ?2);',
      [defaultCompanyName, 'Default Company'],
    );

    final inserted = await db
        .customSelect(
          'SELECT CompanyID FROM Company ORDER BY CompanyID LIMIT 1;',
        )
        .getSingle();
    final id = _asInt(inserted.data['CompanyID']);

    _log.i("🏢 Created default company: $defaultCompanyName (ID=$id)");
    return id;
  }

  Future<int> ensureDefaultCompanyForActiveDb() async {
    return _ensureDefaultCompanyExists(db);
  }

  Future<void> seedDefaultsForCompany(int companyId) async {
    if (companyId <= 0) return;

    final existingForCompany = await db
        .customSelect(
          'SELECT COUNT(1) AS c FROM Acc_Personal WHERE CompanyID = $companyId;',
        )
        .getSingle();
    final currentCount = _asInt(existingForCompany.data['c']);
    if (currentCount > 0) {
      _log.i(
        "ℹ️ CompanyID=$companyId already has Acc_Personal rows ($currentCount). Seed clone skipped.",
      );
      return;
    }

    final raw = await rootBundle.loadString(_firstRunSeedAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) return;

    final sourceRows = _filteredAccPersonalRows(tables['Acc_Personal']);
    if (sourceRows.isEmpty) return;

    final maxAccIdRow = await db
        .customSelect(
          'SELECT COALESCE(MAX(AccID), 0) AS max_id FROM Acc_Personal;',
        )
        .getSingle();
    var nextAccId = _asInt(maxAccIdRow.data['max_id']);

    final clonedRows = <Map<String, dynamic>>[];
    for (final source in sourceRows) {
      final row = Map<String, dynamic>.from(source);
      row['AccID'] = ++nextAccId;
      row['CompanyID'] = companyId;
      clonedRows.add(row);
    }

    await db.transaction(() async {
      await _insertSeedRows(db, "Acc_Personal", clonedRows, "AccID");
    });

    await _ensureAccountCurrencyAssignments(db, companyId: companyId);

    _log.i(
      "✅ Seeded ${clonedRows.length} Acc_Personal rows for CompanyID=$companyId",
    );
  }

  Future<void> _ensureAccountCurrencyAssignments(
    AppDatabase db, {
    int? companyId,
  }) async {
    final currencyRows = await db.customSelect('''
          SELECT AccTypeID
          FROM AccType
          WHERE IsDeleted IS NULL OR IsDeleted = 0
          ORDER BY AccTypeID
          ''').get();
    if (currencyRows.isEmpty) return;

    final accountRows = await db
        .customSelect(
          companyId == null
              ? '''
                SELECT AccID, CompanyID
                FROM Acc_Personal
                WHERE IsDeleted IS NULL OR IsDeleted = 0
                '''
              : '''
                SELECT AccID, CompanyID
                FROM Acc_Personal
                WHERE (IsDeleted IS NULL OR IsDeleted = 0)
                  AND CompanyID = ?1
                ''',
          variables: companyId == null
              ? const []
              : [Variable.withInt(companyId)],
        )
        .get();
    if (accountRows.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      for (final account in accountRows) {
        final accId = _asInt(account.data['AccID']);
        final rowCompanyId = _asInt(account.data['CompanyID']);
        if (accId <= 0 || rowCompanyId <= 0) continue;

        for (final currency in currencyRows) {
          final accTypeId = _asInt(currency.data['AccTypeID']);
          if (accTypeId <= 0) continue;

          await db.customStatement(
            '''
            INSERT OR IGNORE INTO AccountCurrencyMap
              (AccID, AccTypeID, CompanyID, IsEnabled, UpdatedAt)
            VALUES (?1, ?2, ?3, 1, ?4)
            ''',
            [accId, accTypeId, rowCompanyId, now],
          );
        }
      }
    });
  }

  // =====================================================================
  // INTERNAL: Activate DB by path
  // =====================================================================
  Future<void> _activateFromPath(String sqlitePath, {String? email}) async {
    final file = File(sqlitePath);

    if (!file.existsSync()) {
      throw Exception("❌ DB file does not exist: $sqlitePath");
    }

    _log.i(
      "🛠 Activating DB: $sqlitePath for user: ${email ?? activeUserEmail}",
    );

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
    await _ensureDefaultCompanyExists(appDb);
    await _ensureAccountHeadsFromAccPersonal(appDb);

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
      _log.i(
        "🧪 Db_Info after import activation → "
        "rows=${info.length}, email=${info.isNotEmpty ? info.first.emailAddress : 'EMPTY'}",
      );
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
      await _seedFromBundledAssetIfNeeded(db);

      return true; // ✅ DB is now available
    }

    _log.i("📂 Restoring DB for user: $email → $userDbPath");
    await _activateFromPath(userDbPath, email: email);
    await _seedFromBundledAssetIfNeeded(db);
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

  // =====================================================================
  // CLEAR ALL USER DATA (Apple Delete Account support)
  // =====================================================================
  Future<void> clearAllForUser(String email) async {
    _log.w("🧹 clearAllForUser() called for $email");

    // 1️⃣ Delete user DB file
    await clearUserDb(email);

    // 2️⃣ Reset Drift + in-memory state
    await reset();

    _log.i("✅ All local data cleared for $email");
  }
}

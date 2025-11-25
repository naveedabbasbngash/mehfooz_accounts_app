import 'dart:io';
import 'package:logger/logger.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteValidationService {
  final Logger _log = Logger();

  /// ==========================================================
  /// REQUIRED TABLES (must exist)
  /// ==========================================================
  static const List<String> requiredTables = [
    "Acc_Personal",
    "AccType",
    "Company",
    "Db_Info",
    "Transactions_P",
  ];

  /// ==========================================================
  /// REQUIRED COLUMNS: MINIMUM ONLY (based on your REAL DB)
  /// ==========================================================
  static final Map<String, List<List<String>>> requiredColumns = {
    "Acc_Personal": [
      ["AccID"],
      ["Name", "AccName"], // accept either
      ["Address"],
      ["CompanyID"],
    ],

    "AccType": [
      ["AccTypeID"],
      ["AccTypeName"],
    ],

    "Company": [
      ["CompanyID"],
      ["CompanyName"],
    ],

    "Db_Info": [
      ["email_address"],
      ["database_name"],
    ],

    "Transactions_P": [
      ["VoucherNo"],
      ["AccID"],
      ["DR"],
      ["CR"],
    ],
  };

  /// ==========================================================
  /// VALIDATE THE IMPORTED DATABASE
  /// ==========================================================
  Future<void> validateDatabase(String sqlitePath) async {
    final file = File(sqlitePath);

    if (!await file.exists()) {
      throw Exception("❌ Database file not found at: $sqlitePath");
    }

    _log.i("🔍 Validating SQLite database: $sqlitePath");

    final db = sqlite3.open(sqlitePath);

    try {
      _validateTables(db);
      _validateColumns(db);
    } finally {
      db.dispose();
    }

    _log.i("✅ SQLite validation PASSED.");
  }

  /// ==========================================================
  /// CHECK TABLES
  /// ==========================================================
  void _validateTables(Database db) {
    final result =
    db.select("SELECT name FROM sqlite_master WHERE type='table'");

    final existing = result.map((e) => (e['name'] as String).toLowerCase()).toList();

    for (final table in requiredTables) {
      if (!existing.contains(table.toLowerCase())) {
        throw Exception("❌ Missing required table: $table");
      }
    }

    _log.i("📦 All required tables exist.");
  }

  /// ==========================================================
  /// CHECK REQUIRED COLUMNS (supports flexible names)
  /// ==========================================================
  void _validateColumns(Database db) {
    for (final entry in requiredColumns.entries) {
      final table = entry.key;
      final columnGroups = entry.value;

      final pragma = db.select("PRAGMA table_info('$table')");
      final existingCols =
      pragma.map((row) => (row['name'] as String).toLowerCase()).toList();

      for (final group in columnGroups) {
        // at least ONE of the variants must exist
        final ok = group.any((col) => existingCols.contains(col.toLowerCase()));

        if (!ok) {
          throw Exception(
              "❌ Table '$table' missing required column: ${group.join(" or ")}");
        }
      }
    }

    _log.i("🧱 All required columns present.");
  }
}
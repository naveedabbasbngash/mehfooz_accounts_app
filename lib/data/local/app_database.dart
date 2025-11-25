import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

/// =============================================================
///  DRIFT MAIN DATABASE CLASS
///  - Works with imported SQLite DB
///  - Future-proof (schemaVersion = 1)
///  - Uses NativeDatabase for iOS + Android
///  - Fully compatible with DatabaseManager
/// =============================================================

@DriftDatabase(
  tables: [
    AccPersonal,
    AccType,
    CompanyTable,
    DbInfoTable,
    TransactionsP,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  /// Keep schemaVersion = 1 ALWAYS.
  /// Your DB comes from an external source (desktop/exported).
  /// You do NOT use Drift migrations.
  @override
  int get schemaVersion => 1;

  /// -----------------------------------------------------------------------
  /// Create Drift database from an imported SQLite file.
  /// This is the ONLY database your app uses.
  /// -----------------------------------------------------------------------
  static Future<AppDatabase> fromImportedFile(File sqliteFile) async {
    final executor = NativeDatabase(
      sqliteFile,
      logStatements: false,
    );

    return AppDatabase(executor);
  }

  /// OPTIONAL: If you ever need a temporary in-memory DB during debugging
  static AppDatabase createInMemory() {
    return AppDatabase(NativeDatabase.memory());
  }
}
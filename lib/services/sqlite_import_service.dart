import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

// IMPORTANT: this is the missing import
import 'package:sqlite3/sqlite3.dart';

class SqliteImportService {
  static final Logger _log = Logger();

  /// =======================================================================
  /// IMPORT a `.sqlite` database from share intent, file picker, downloads,
  /// WhatsApp, Gmail, or ANY external software.
  ///
  /// Returns: path to INTERNAL SAFE COPY (or null on failure)
  /// =======================================================================
  static Future<String?> importAndSaveDb(String originalPath) async {
    try {
      final file = File(originalPath);

      if (!await file.exists()) {
        _log.e("❌ SQLite file does not exist: $originalPath");
        return null;
      }

      final ext = p.extension(originalPath).toLowerCase();
      if (ext != ".sqlite" && ext != ".db") {
        _log.e("❌ Unsupported file extension: $ext");
        return null;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(p.join(appDir.path, "imported_databases"));

      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
        _log.i("📁 Created internal DB folder: ${dbDir.path}");
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "imported_$timestamp.sqlite";

      final newPath = p.join(dbDir.path, fileName);

      await file.copy(newPath);

      _log.i("📦 Imported DB saved → $newPath");

      return newPath;
    } catch (e, st) {
      _log.e("❌ ERROR during DB import", error: e, stackTrace: st);
      return null;
    }
  }

  /// =======================================================================
  /// List all tables in the imported SQLite file.
  /// Uses sqlite3 engine (same used by Drift).
  /// =======================================================================
  static Future<List<String>> getTables(String dbPath) async {
    try {
      final db = sqlite3.open(dbPath);

      final result = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );

      final tables = result.map((row) => row['name'] as String).toList();

      db.dispose();
      return tables;
    } catch (e, st) {
      _log.e("❌ Failed to read table list: $e", error: e, stackTrace: st);
      return [];
    }
  }


  static Future<String> writeBytesToTemp(ByteData data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/apple_review_demo.sqlite');

    final buffer = data.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    return file.path;
  }
}
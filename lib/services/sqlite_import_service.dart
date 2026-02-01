import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

// IMPORTANT: sqlite engine (same as Drift)
import 'package:sqlite3/sqlite3.dart';

class SqliteImportService {
  static final Logger _log = Logger();

  // 🔑 iOS security-scoped channel
  static const MethodChannel _icloudChannel =
  MethodChannel('icloud_file_access');

  /// =======================================================================
  /// IMPORT a `.sqlite` database from share intent, file picker, iOS Open-In,
  /// WhatsApp, Gmail, Files app, iCloud, etc.
  ///
  /// ✅ Always copies file into INTERNAL app directory
  /// ✅ Handles Inbox + iCloud correctly
  ///
  /// Returns: INTERNAL SAFE PATH (or null on failure)
  /// =======================================================================
  static Future<String?> importAndSaveDb(String originalPath) async {
    try {
      _log.i("📥 Import request → $originalPath");

      // iOS sometimes passes file://
      final cleanPath = originalPath.startsWith("file://")
          ? originalPath.replaceFirst("file://", "")
          : originalPath;

      // 🔥 HANDLE iCLOUD FILES
      final resolvedPath = await _resolveIOSPathIfNeeded(cleanPath);
      if (resolvedPath == null) {
        _log.e("❌ iCloud access denied");
        return null;
      }

      final sourceFile = File(resolvedPath);

      if (!await sourceFile.exists()) {
        _log.e("❌ SQLite file does not exist: $resolvedPath");
        return null;
      }

      final ext = p.extension(resolvedPath).toLowerCase();
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

      _log.i("📦 Copying DB → $newPath");
      final copiedFile = await sourceFile.copy(newPath);

      // 🔥 IMPORTANT: iOS Inbox cleanup
      if (resolvedPath.contains("/Documents/Inbox/")) {
        try {
          sourceFile.deleteSync();
          _log.i("🧹 Cleaned up iOS Inbox file");
        } catch (_) {
          _log.w("⚠️ Could not delete Inbox file (safe to ignore)");
        }
      }

      // 🔍 Sanity check (same engine Drift uses)
      try {
        final db = sqlite3.open(copiedFile.path);
        db.dispose();
        _log.i("✅ SQLite file verified successfully");
      } catch (e) {
        _log.e("❌ Copied file is not a valid SQLite DB");
        return null;
      }

      _log.i("✅ Import completed → ${copiedFile.path}");
      return copiedFile.path;
    } catch (e, st) {
      _log.e("❌ ERROR during DB import", error: e, stackTrace: st);
      return null;
    }
  }

  /// =======================================================================
  /// iOS ONLY: Resolve iCloud / Files paths using security-scoped access
  /// =======================================================================
  static Future<String?> _resolveIOSPathIfNeeded(String path) async {
    if (!Platform.isIOS) return path;

    // Only iCloud paths need native help
    if (!path.contains("com~apple~CloudDocs")) {
      return path;
    }

    _log.i("🔐 Requesting iCloud security-scoped access");

    final copiedPath = await _icloudChannel.invokeMethod<String>(
      "copyFromICloud",
      path,
    );

    if (copiedPath != null) {
      _log.i("📂 iCloud file copied → $copiedPath");
    }

    return copiedPath;
  }

  /// =======================================================================
  /// List tables in imported SQLite
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
      _log.e("❌ Failed to read table list", error: e, stackTrace: st);
      return [];
    }
  }

  /// =======================================================================
  /// Apple review / demo helper
  /// =======================================================================
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
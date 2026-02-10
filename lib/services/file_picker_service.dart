import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  static Future<String?> pickSqliteFile() async {
    final bool isIOS = Platform.isIOS;
    final bool isAndroid = Platform.isAndroid;

    debugPrint("📌 [FilePicker] platform=${Platform.operatingSystem}");

    // Simulator-only convenience
    String? initialDirectory;
    final bool isSim = isIOS && Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
    if (isSim) {
      final user = Platform.environment['USER'];
      if (user != null) {
        initialDirectory = "/Users/$user/Desktop";
        debugPrint("📌 [FilePicker] simulator initialDirectory=$initialDirectory");
      }
    }

    try {
      // ✅ iOS: FileType.any is most reliable
      // ✅ Android: we can keep custom filter
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: isIOS ? FileType.any : FileType.custom,
        allowedExtensions: isIOS ? null : ['sqlite', 'db'],
        initialDirectory: initialDirectory,
        withData: false,
      );

      if (result == null) {
        debugPrint("⚠️ [FilePicker] user canceled");
        return null;
      }

      final file = result.files.single;
      debugPrint("✅ [FilePicker] name=${file.name}");
      debugPrint("✅ [FilePicker] path=${file.path}");
      debugPrint("✅ [FilePicker] size=${file.size}");

      final path = file.path;
      if (path == null) {
        debugPrint("❌ [FilePicker] path is null (iOS provider returned no path)");
        return null;
      }

      final lower = path.toLowerCase();
      if (!lower.endsWith('.sqlite') && !lower.endsWith('.db')) {
        debugPrint("❌ [FilePicker] invalid extension: $path");
        throw Exception("Please select a .sqlite or .db file.");
      }

      debugPrint("🟢 [FilePicker] VALID SQLite selected");
      return path;
    } catch (e, st) {
      debugPrint("🔥 [FilePicker] ERROR: $e");
      debugPrint("🔥 [FilePicker] STACK: $st");
      rethrow;
    }
  }
}
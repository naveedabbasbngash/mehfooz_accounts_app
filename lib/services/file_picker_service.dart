import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  static Future<String?> pickSqliteFile() async {
    bool isSim =
        Platform.isIOS && Platform.environment['SIMULATOR_DEVICE_NAME'] != null;

    String? initialDirectory;

    if (isSim) {
      final user = Platform.environment['USER'];
      initialDirectory = "/Users/$user/Desktop";
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
      initialDirectory: initialDirectory,
    );

    if (result == null) return null;
    return result.files.single.path;
  }
}
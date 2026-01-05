// lib/services/pdf/pdf_file_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<File> saveTempPdf(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
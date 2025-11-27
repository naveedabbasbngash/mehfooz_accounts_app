import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class OpenFileService {
  static Future<void> openPdf(BuildContext context, File file) async {
    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot open PDF: ${result.message}")),
      );
    }
  }
}
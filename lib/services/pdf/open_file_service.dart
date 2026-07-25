import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class OpenFileService {
  static Future<void> openPdf(BuildContext context, File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final sw = Stopwatch()..start();
    debugPrint("[LedgerPerf][OpenFile] start path=${file.path}");
    final result = await OpenFilex.open(file.path);
    sw.stop();
    debugPrint(
      "[LedgerPerf][OpenFile] done type=${result.type} "
      "message='${result.message}' elapsedMs=${sw.elapsedMilliseconds}",
    );

    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(content: Text("Cannot open PDF: ${result.message}")),
      );
    }
  }
}

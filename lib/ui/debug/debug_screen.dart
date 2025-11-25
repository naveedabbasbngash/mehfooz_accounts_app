import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class DebugDbScreen extends StatefulWidget {
  final String dbPath;
  const DebugDbScreen({super.key, required this.dbPath});

  @override
  State<DebugDbScreen> createState() => _DebugDbScreenState();
}

class _DebugDbScreenState extends State<DebugDbScreen> {
  String output = "Loading...";

  @override
  void initState() {
    super.initState();
    debugDb();
  }

  Future<void> debugDb() async {
    try {
      final db = await openDatabase(widget.dbPath);

      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");

      String result = "📌 TABLE LIST:\n\n";

      for (var t in tables) {
        final tableName = t['name'];
        result += "===== $tableName =====\n";

        final columns = await db.rawQuery("PRAGMA table_info($tableName)");
        for (var col in columns) {
          result += "• ${col['name']}   (${col['type']})\n";
        }

        result += "\n";
      }

      await db.close();

      setState(() => output = result);
    } catch (e) {
      setState(() => output = "❌ ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Database Debug")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(output),
      ),
    );
  }
}
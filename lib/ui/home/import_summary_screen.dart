import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/sqlite_validation_service.dart';
import '../../services/sqlite_import_service.dart';
import '../../data/local/database_manager.dart';
import '../../repository/account_repository.dart';
import '../../model/pending_amount_row.dart';
import 'home_wrapper.dart';
import '../../model/user_model.dart';

class ImportSummaryScreen extends StatefulWidget {
  final String filePath;
  final UserModel user;

  const ImportSummaryScreen({
    super.key,
    required this.filePath,
    required this.user,
  });

  @override
  State<ImportSummaryScreen> createState() => _ImportSummaryScreenState();
}

class _ImportSummaryScreenState extends State<ImportSummaryScreen> {
  final Logger _log = Logger();

  List<String> tables = [];
  bool isLoading = true;
  bool isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => isLoading = true);

    try {
      tables = await SqliteImportService.getTables(widget.filePath);
      _log.i("📄 Tables found: $tables");
    } catch (e) {
      _log.e("❌ Failed to read tables: $e");
    }

    setState(() => isLoading = false);
  }

  /// ===========================================================
  /// ACTIVATE DB → VALIDATE → LOAD PENDING AMOUNTS → GO HOME
  /// ===========================================================
  Future<void> _activateAndProceed() async {
    setState(() => isActivating = true);

    try {
      // Step 1: Validate schema
      final validator = SqliteValidationService();
      await validator.validateDatabase(widget.filePath);

      // Step 2: Activate database
      List<PendingAmountRow> pendingSummary = [];

      await DatabaseManager.instance.activateAndThen(
        widget.filePath,
            (db) async {
          final repo = AccountRepository(db);

          // Load selected CompanyID
          final prefs = await SharedPreferences.getInstance();
          final storedId = prefs.getInt("selected_company_id");

          final companyId = storedId ?? 0; // fallback

          // ⭐ FIX — Call with named parameter
          pendingSummary = await repo.getPendingAmountSummary(
            selectedCompanyId: companyId,
          );
        },
      );

      // Step 3: Navigate to HomeWrapper
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeWrapper(
            user: widget.user,
            sliderDrawerKey: GlobalKey(),
          ),
        ),
            (route) => false,
      );
    } catch (e, st) {
      _log.e("❌ Failed to activate DB", error: e, stackTrace: st);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import failed: $e")),
        );
      }
    } finally {
      setState(() => isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Import Summary"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Imported: ${widget.filePath}",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            const Text(
              "📁 Tables Found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : tables.isEmpty
                  ? const Center(child: Text("⚠ No tables found."))
                  : ListView.builder(
                itemCount: tables.length,
                itemBuilder: (_, i) {
                  return Card(
                    child: ListTile(
                      title: Text(tables[i]),
                      leading: const Icon(Icons.table_chart),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ACTIVATE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isActivating
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check_circle),
                label: Text(
                  isActivating ? "Activating..." : "Activate & Open App",
                ),
                onPressed: isActivating ? null : _activateAndProceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
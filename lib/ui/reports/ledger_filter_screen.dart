import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/reports/ledger_filter_view_model.dart';
import '../../services/pdf/ledger_pdf_service.dart';
import '../../services/pdf/open_file_service.dart';
import '../../services/global_state.dart';

class LedgerFilterScreen extends StatefulWidget {
  const LedgerFilterScreen({super.key});

  @override
  State<LedgerFilterScreen> createState() => _LedgerFilterScreenState();
}

class _LedgerFilterScreenState extends State<LedgerFilterScreen> {
  final accountController = TextEditingController();
  final currencyController = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();

  final dateFmtHuman = DateFormat('dd/MM/yyyy');
  final dateFmtDb = DateFormat('yyyy-MM-dd');

  bool showSuggestions = false;
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final vm = context.read<LedgerFilterViewModel>();
      vm.loadCurrencies();

      // Default period → last 30 days
      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));

      fromDateController.text = dateFmtHuman.format(lastMonth);
      toDateController.text = dateFmtHuman.format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerFilterViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        title: const Text(
          "Ledger Filter",
          style: TextStyle(
            color: Color(0xFF0B1E3A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          _buildBody(context, vm),

          if (isGenerating)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN UI BODY
  // -------------------------------------------------------------
  Widget _buildBody(BuildContext context, LedgerFilterViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        children: [
          // ---------------------- MAIN CARD ----------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filter Options",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1E3A),
                  ),
                ),

                const SizedBox(height: 20),

                // -------------------------------------------------
                // ACCOUNT SEARCH
                // -------------------------------------------------
                TextField(
                  controller: accountController,
                  decoration: const InputDecoration(
                    labelText: "Search account by name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (txt) {
                    if (txt.trim().isEmpty) {
                      setState(() => showSuggestions = false);
                      return;
                    }
                    vm.searchAccounts(txt);
                    setState(() => showSuggestions = true);
                  },
                ),

                if (showSuggestions && vm.accountSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.deepPurple.shade100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: vm.accountSuggestions
                          .map(
                            (s) => ListTile(
                          dense: true,
                          title: Text(s),
                          onTap: () {
                            accountController.text = s;
                            setState(() => showSuggestions = false);
                          },
                        ),
                      )
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 20),

                // -------------------------------------------------
                // CURRENCY DROPDOWN
                // -------------------------------------------------
                TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(
                    labelText: "Currency",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                if (currencyController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.deepPurple.shade100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: vm.currencies
                          .where((c) => c
                          .toLowerCase()
                          .contains(currencyController.text.toLowerCase()))
                          .map(
                            (c) => ListTile(
                          dense: true,
                          title: Text(c),
                          onTap: () {
                            currencyController.text = c;
                            FocusScope.of(context).unfocus();
                            setState(() {});
                          },
                        ),
                      )
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 20),

                // -------------------------------------------------
                // DATE RANGE
                // -------------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        label: "From date",
                        controller: fromDateController,
                        onPick: () => _pickDate(fromDateController),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        label: "To date",
                        controller: toDateController,
                        onPick: () => _pickDate(toDateController),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------
                // SHOW BUTTON
                // -------------------------------------------------
                ElevatedButton(
                  onPressed: () async => _onGeneratePressed(context, vm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1E3A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Show Ledger",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // DATE FIELD
  // -------------------------------------------------------------
  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onPick,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onPick,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_month),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final init = dateFmtHuman.parse(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = dateFmtHuman.format(picked);
      setState(() {});
    }
  }

  // -------------------------------------------------------------
  // GENERATE PDF
  // -------------------------------------------------------------
  Future<void> _onGeneratePressed(
      BuildContext context,
      LedgerFilterViewModel vm,
      ) async {
    final acc = accountController.text.trim();
    final cur = currencyController.text.trim();

    if (acc.isEmpty || cur.isEmpty) {
      _toast("Please select account and currency");
      return;
    }

    final fromHuman = fromDateController.text.trim();
    final toHuman = toDateController.text.trim();

    final from = dateFmtDb.format(dateFmtHuman.parse(fromHuman));
    final to = dateFmtDb.format(dateFmtHuman.parse(toHuman));

    setState(() => isGenerating = true);

    final result = await vm.loadLedger(
      accountName: acc,
      currency: cur,
      fromDate: from,
      toDate: to,
    );

    setState(() => isGenerating = false);

    if (result == null) {
      _toast("No ledger data found");
      return;
    }

    final file = await LedgerPdfService.instance.render(
      officeName: GlobalState.instance.companyName,
      accountName: acc,
      currency: cur,
      periodText: "Period: $fromHuman — $toHuman",
      result: result,
    );

    OpenFileService.openPdf(context, file);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
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
  double _pdfProgress = 0.0;
  String _pdfStageText = "Preparing...";
  int _pdfPagesDone = 0;
  int _pdfPagesTotal = 0;
  bool _pdfPagesEstimated = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
          _buildBody(vm),

          if (isGenerating)
            _buildGeneratingOverlay(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN UI BODY
  // -------------------------------------------------------------
  Widget _buildBody(LedgerFilterViewModel vm) {
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
                  color: Colors.black.withValues(alpha: 0.06),
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
                  onPressed: isGenerating
                      ? null
                      : () async => _onGeneratePressed(vm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded),
                      SizedBox(width: 8),
                      Text(
                        "Show Ledger",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
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
      LedgerFilterViewModel vm,
      ) async {
    if (isGenerating) return;

    final acc = accountController.text.trim();
    final cur = currencyController.text.trim();

    if (acc.isEmpty || cur.isEmpty) {
      _toast("Please select account and currency");
      return;
    }

    final fromHuman = fromDateController.text.trim();
    final toHuman = toDateController.text.trim();

    final from = dateFmtDb.format(dateFmtHuman.parse(fromHuman));
    final toExclusive = dateFmtDb.format(
      dateFmtHuman.parse(toHuman).add(const Duration(days: 1)),
    );
    final totalSw = Stopwatch()..start();
    debugPrint(
      "[LedgerPerf][UI] start account='$acc' currency='$cur' "
      "from=$from toExclusive=$toExclusive",
    );

    setState(() => isGenerating = true);
    setState(() {
      _pdfProgress = 0.02;
      _pdfStageText = "Loading transactions...";
      _pdfPagesDone = 0;
      _pdfPagesTotal = 0;
      _pdfPagesEstimated = true;
    });
    try {
      final loadSw = Stopwatch()..start();
      final result = await vm.loadLedger(
        accountName: acc,
        currency: cur,
        fromDate: from,
        toDateExclusive: toExclusive,
      );
      loadSw.stop();
      debugPrint(
        "[LedgerPerf][UI] vmLoad:done elapsedMs=${loadSw.elapsedMilliseconds} "
        "rows=${result?.rows.length ?? 0}",
      );

      if (!mounted) return;

      if (result == null) {
        totalSw.stop();
        debugPrint(
          "[LedgerPerf][UI] abort:no-data totalElapsedMs=${totalSw.elapsedMilliseconds}",
        );
        _toast("No ledger data found");
        return;
      }

      final estimatedPages = _estimatePages(result.rows.length);
      if (mounted) {
        setState(() {
          _pdfProgress = 0.16;
          _pdfStageText = "Preparing PDF...";
          _pdfPagesDone = 0;
          _pdfPagesTotal = estimatedPages;
          _pdfPagesEstimated = true;
        });
      }

      final pdfSw = Stopwatch()..start();
      final file = await LedgerPdfService.instance.render(
        officeName: GlobalState.instance.companyName,
        accountName: acc,
        currency: cur,
        periodText: "Period: $fromHuman - $toHuman",
        result: result,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _pdfProgress = progress.progress;
            _pdfStageText = progress.message;
            _pdfPagesDone = progress.pagesDone;
            _pdfPagesTotal = progress.pagesTotal;
            _pdfPagesEstimated = progress.estimated;
          });
        },
      );
      pdfSw.stop();
      final fileBytes = await file.length();
      debugPrint(
        "[LedgerPerf][UI] pdfRender:done path=${file.path} bytes=$fileBytes "
        "elapsedMs=${pdfSw.elapsedMilliseconds}",
      );

      if (!mounted) return;
      final openSw = Stopwatch()..start();
      await OpenFileService.openPdf(context, file);
      openSw.stop();
      totalSw.stop();
      debugPrint(
        "[LedgerPerf][UI] openFile:done elapsedMs=${openSw.elapsedMilliseconds} "
        "totalElapsedMs=${totalSw.elapsedMilliseconds}",
      );
    } catch (e) {
      totalSw.stop();
      debugPrint(
        "[LedgerPerf][UI] error='$e' totalElapsedMs=${totalSw.elapsedMilliseconds}",
      );
      if (!mounted) return;
      _toast("Failed to generate ledger PDF");
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  Widget _buildGeneratingOverlay() {
    final totalPages = _pdfPagesTotal > 0 ? _pdfPagesTotal : 1;
    final donePages = _pdfPagesDone.clamp(0, totalPages);
    final remainingPages = (totalPages - donePages).clamp(0, totalPages);
    final progressValue = (_pdfProgress > 0 && _pdfProgress < 1)
        ? _pdfProgress
        : null;

    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 74,
                      height: 74,
                      child: CircularProgressIndicator(
                        strokeWidth: 4.4,
                        value: progressValue,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 34,
                      color: Colors.red.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "Generating Ledger PDF",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0B1E3A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pdfStageText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _pdfPagesEstimated
                      ? "Estimated pages: $donePages / $totalPages  •  Remaining: $remainingPages"
                      : "Pages: $donePages / $totalPages  •  Remaining: $remainingPages",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _estimatePages(int rowsCount) {
    const rowsPerPageEstimate = 28;
    final pages = (rowsCount / rowsPerPageEstimate).ceil();
    return pages <= 0 ? 1 : pages;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

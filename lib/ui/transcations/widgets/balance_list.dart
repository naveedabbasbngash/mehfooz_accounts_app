import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/balance_currency_ui.dart';

class BalanceList extends StatefulWidget {
  final String name;
  final List<BalanceCurrencyUi> rows;

  /// PDF export callback (handled by parent / ViewModel)
  final Future<void> Function()? onExportPdf;

  const BalanceList({
    super.key,
    required this.name,
    required this.rows,
    this.onExportPdf,
  });

  @override
  State<BalanceList> createState() => _BalanceListState();
}

class _BalanceListState extends State<BalanceList> {
  bool _exporting = false;

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _fmtDouble(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v;
    return _fmt.format(safe);
  }

  bool _isZero(double v) => v.abs() < 0.005;

  // ------------------------------------------------------------
  // ✅ SAFE PDF HANDLER (GOOGLE STYLE)
  // ------------------------------------------------------------
  Future<void> _handleExportPdf() async {
    if (widget.onExportPdf == null || _exporting) return;

    setState(() => _exporting = true);

    try {
      await widget.onExportPdf!();
    } catch (e) {
      debugPrint("❌ PDF export failed: $e");
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = widget.rows.where((r) {
      return !_isZero(r.credit) ||
          !_isZero(r.debit) ||
          !_isZero(r.balance);
    }).toList();

    if (visibleRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.name.trim().isEmpty
                ? "Type a name to view balance"
                : "No balance data for this person",
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final balanceWidth = screenWidth * 0.28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ================= HEADER WITH PDF BUTTON =================
        if (widget.name.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Balance • ${widget.name}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0B1E3A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // ---------------- PDF BUTTON ----------------
                _exporting
                    ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : IconButton(
                  tooltip: "Export PDF",
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(0xFFC62828),
                  ),
                  onPressed: _handleExportPdf,
                ),
              ],
            ),
          ),

        const Divider(height: 1, color: Color(0x14000000)),

        // ================= LIST =================
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: visibleRows.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0x14000000)),
            itemBuilder: (_, i) {
              final row = visibleRows[i];
              final bal = row.balance;

              final Color balColor =
              bal >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

              return Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        row.currency.isEmpty
                            ? "?"
                            : row.currency.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // MIDDLE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.currency.isEmpty
                                ? "Unknown currency"
                                : row.currency,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1E3A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (!_isZero(row.credit)) ...[
                                const Text("Cr",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280))),
                                Text(_fmtDouble(row.credit),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w600)),
                              ],
                              if (!_isZero(row.debit)) ...[
                                const Text("Dr",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280))),
                                Text(_fmtDouble(row.debit),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // RIGHT
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: balanceWidth,
                        minWidth: 80,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Balance",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDouble(bal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: balColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
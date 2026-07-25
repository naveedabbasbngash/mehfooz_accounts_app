import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../model/balance_currency_ui.dart';
import '../../../services/share/balance_share_full_image_service.dart';
import '../../commons/currency_flag.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

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
  bool _sharing = false;

  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _fmtDouble(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v;
    return _fmt.format(safe);
  }

  bool _isZero(double v) => v.abs() < 0.005;

  String _countryNameForCurrency(String currency) =>
      currencyCountryName(currency);

  List<BalanceCurrencyUi> _visibleRows() {
    return widget.rows.where((r) {
      return !_isZero(r.balance);
    }).toList();
  }

  Future<void> _handleShareImage() async {
    if (_sharing) return;

    final visibleRows = _visibleRows();
    if (visibleRows.isEmpty) return;

    setState(() => _sharing = true);

    try {
      final file = await BalanceShareFullImageService.instance.render(
        name: widget.name,
        rows: visibleRows,
      );

      final title = widget.name.trim().isEmpty
          ? 'Balance Summary'
          : 'Balance • ${widget.name.trim()}';

      await Share.shareXFiles([XFile(file.path)], text: title, subject: title);
    } catch (e) {
      debugPrint('❌ Share image failed: $e');
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  // ------------------------------------------------------------
  // ✅ SAFE PDF HANDLER (GOOGLE STYLE)
  // ------------------------------------------------------------
  Future<void> _handleExportPdf() async {
    if (widget.onExportPdf == null || _exporting) return;

    setState(() => _exporting = true);

    try {
      await widget.onExportPdf!();
    } catch (e) {
      debugPrint('❌ PDF export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows();

    if (visibleRows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kTxBrandBlue.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _kTxBrandBlue.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kTxBrandBlue.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _kTxBrandBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.name.trim().isEmpty
                      ? 'Type a name to view balance'
                      : 'No balance data for this person',
                  style: const TextStyle(
                    color: Color(0xFF16324B),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ================= HEADER WITH ACTIONS =================
        if (widget.name.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Balance • ${widget.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0B1E3A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _sharing
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Share Image',
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          color: _kTxBrandBlue,
                        ),
                        onPressed: _handleShareImage,
                      ),
                _exporting
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Export PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: _kTxBrandBlue,
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: visibleRows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = visibleRows[i];
              final bal = row.balance;
              final currencyLabel = row.currency.isEmpty
                  ? 'Unknown currency'
                  : row.currency;
              final countryName = _countryNameForCurrency(currencyLabel);
              final isPositive = bal >= 0;

              final Color balColor = isPositive
                  ? _kTxBrandBlue
                  : const Color(0xFFC62828);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: CurrencyFlagBadge(
                        currency: currencyLabel,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currencyLabel,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1E3A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            countryName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? _kTxBrandBlue.withValues(alpha: 0.08)
                            : const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPositive
                              ? _kTxBrandBlue.withValues(alpha: 0.18)
                              : const Color(0xFFF6C9C9),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmtDouble(bal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15.5,
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

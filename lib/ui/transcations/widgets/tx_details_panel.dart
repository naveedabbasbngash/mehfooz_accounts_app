// lib/ui/transactions/widgets/tx_details_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

import '../../../model/tx_item_ui.dart';
import '../../../services/pdf/transaction_voucher_pdf_service.dart';

class TxDetailsPanel extends StatelessWidget {
  final TxItemUi row;
  final VoidCallback onClose;

  const TxDetailsPanel({
    super.key,
    required this.row,
    required this.onClose,
  });

  // ------------------------------------------------------------
  // Decimal formatter (REAL money)
  // ------------------------------------------------------------
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  String _fmtDouble(double v) {
    final safe = v.abs() < 0.005 ? 0.0 : v; // kill -0.00
    return _fmt.format(safe);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCredit = row.cr > 0;
    final double amount = row.amount;

    final Color amountColor =
    isCredit ? AppColors.success : AppColors.error;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              blurRadius: 25,
              spreadRadius: 4,
              color: Colors.black.withOpacity(0.18),
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------------------
              // HEADER
              // ------------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Voucher #${row.voucherNo}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),

                  // PDF BUTTON
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _exportPdf(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.12),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // CLOSE
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(color: AppColors.divider),

              // ------------------------------------------------------------
              // INFO
              // ------------------------------------------------------------
              const SizedBox(height: 16),
              _info("Name", row.name),
              _info("Date", row.date),
              _info("Currency", row.currency),

              if ((row.description ?? "").isNotEmpty)
                _info("Description", row.description!),

              const SizedBox(height: 22),

              // ------------------------------------------------------------
              // AMOUNT
              // ------------------------------------------------------------
              Center(
                child: Text(
                  "${isCredit ? '+' : '-'}${_fmtDouble(amount)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Info row
  // ------------------------------------------------------------
  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PDF Export
  // ------------------------------------------------------------
  Future<void> _exportPdf(BuildContext context) async {
    try {
      final file = await TxDetailsPdfService.instance.render(row);
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to generate PDF: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
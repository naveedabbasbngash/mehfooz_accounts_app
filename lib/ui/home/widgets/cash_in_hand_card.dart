import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../services/pdf/export_summary_pdf.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/fade_slide.dart';

class CashInHandCard extends StatelessWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

  final NumberFormat fmt = NumberFormat('#,##0.00');

  CashInHandCard({
    super.key,
    required this.vm,
    required this.isExpanded,
    required this.onToggle,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final rows = vm.cashInHandSummary;
    final hasData = rows.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: hasData ? _buildContent(context, rows) : _emptyState(),
    );
  }

  Column _buildContent(BuildContext context, List<dynamic> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(context),
        const SizedBox(height: 4),

        Text(
          "Summary by currency",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),

        const SizedBox(height: 10),

        Divider(height: 16, color: AppColors.divider),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              ..._buildRows(rows),
              if (rows.length > maxVisible)
                _buildExpandToggle(rows.length - maxVisible),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Title Row
  // ----------------------------------------------------------
  Row _titleRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.savings_outlined, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          "JB Amount",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.picture_as_pdf, color: AppColors.primary),
          tooltip: "Share PDF",
          onPressed: () => _exportCombinedPdf(context, vm),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Build rows — NOW USING PRIMARY COLOR
  // ----------------------------------------------------------
  List<Widget> _buildRows(List<dynamic> rows) {
    final visible = isExpanded ? rows.length : rows.length.clamp(0, maxVisible);

    return List.generate(visible, (i) {
      final row = rows[i];
      final isPositive = row.amount >= 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(row.currency, style: const TextStyle(fontWeight: FontWeight.w600)),

            Text(
              fmt.format(row.amount),
              style: TextStyle(
                color: isPositive ? AppColors.primary : AppColors.error, // ← FIXED
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ----------------------------------------------------------
  // Expand / collapse toggle
  // ----------------------------------------------------------
  Widget _buildExpandToggle(int hiddenCount) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              isExpanded ? "Show less" : "+ $hiddenCount more",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Empty State — PROFESSIONAL LIGHT BACKGROUND
  // ----------------------------------------------------------
  Widget _emptyState() {
    return FadeSlide(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: Icon(Icons.wallet_outlined,
                  size: 40, color: AppColors.primary.withOpacity(0.35)),
            ),

            const SizedBox(height: 16),

            Text(
              "No Summary Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "JB Amount summary will appear\nonce transaction data is available.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.emptyBackground,     // ← FIXED
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.primary.withOpacity(0.45)),
                  const SizedBox(width: 6),
                  Text(
                    "Import database to load summary",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withOpacity(0.45),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Card decoration
  // ----------------------------------------------------------
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.cardShadow,
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: AppColors.divider),
  );
}

// ----------------------------------------------------------
// PDF export
// ----------------------------------------------------------
void _exportCombinedPdf(BuildContext context, HomeViewModel vm) async {
  final companyName = vm.selectedCompanyName ?? "Mahfooz Accounts";

  final file = await SummaryCombinedPdfService.instance.render(
    companyName: companyName,
    jbRows: vm.cashInHandSummary,
    acc1Rows: vm.acc1CashSummary,
  );

  await OpenFilex.open(file.path);
}
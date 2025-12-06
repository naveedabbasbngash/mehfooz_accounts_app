import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart' show AppColors;
import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/fade_slide.dart';

class Acc1SummaryCard extends StatelessWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

  // Number formatter
  final NumberFormat fmt = NumberFormat('#,##0.00');

  Acc1SummaryCard({
    super.key,
    required this.vm,
    required this.isExpanded,
    required this.onToggle,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final rows = vm.acc1CashSummary;
    final hasData = rows.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: hasData
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(),
          const SizedBox(height: 8),
          Divider(
            height: 16,
            color: AppColors.cardBackground,          // ← UPDATED
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                ..._buildRows(rows),
                if (rows.length > maxVisible)
                  _expandToggle(rows.length - maxVisible),
              ],
            ),
          ),
        ],
      )
          : _emptyState(),
    );
  }

  // ------------------------------------------------------------
  // Title Row
  // ------------------------------------------------------------
  Row _titleRow() {
    return Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.primary,                   // ← UPDATED
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          "Cash In Hand",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,                // ← UPDATED
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Visible rows with comma formatting
  // ------------------------------------------------------------
  List<Widget> _buildRows(List<dynamic> rows) {
    final total = rows.length;
    final visibleCount = isExpanded ? total : total.clamp(0, maxVisible);

    return List.generate(visibleCount, (i) {
      final row = rows[i];
      final isPositive = row.amount >= 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              row.currency,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              fmt.format(row.amount),
              style: TextStyle(
                color: isPositive
                    ? AppColors.success                 // ← UPDATED
                    : AppColors.error,                 // ← UPDATED
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ------------------------------------------------------------
  // Expand / collapse
  // ------------------------------------------------------------
  Widget _expandToggle(int hiddenCount) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primary,               // ← UPDATED
            ),
            const SizedBox(width: 5),
            Text(
              isExpanded ? "Show less" : "+ $hiddenCount more",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,             // ← UPDATED
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Empty State (with FADE + SLIDE)
  // ------------------------------------------------------------
  Widget _emptyState() {
    return FadeSlide(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08), // ← UPDATED
              ),
              child: Icon(
                Icons.wallet_outlined,
                size: 40,
                color: AppColors.primary.withOpacity(0.35), // ← UPDATED
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "No Cash Summary Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Cash-in-hand information will appear\nonce transactions are available.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.greyDark,             // ← UPDATED
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.highlight,            // ← UPDATED
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary.withOpacity(0.45),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Import a database to load summary",
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

  // ------------------------------------------------------------
  // Card Decoration
  // ------------------------------------------------------------
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.cardBackground,                    // ← UPDATED
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.cardShadow,             // ← UPDATED
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(color: AppColors.divider),
  );
}
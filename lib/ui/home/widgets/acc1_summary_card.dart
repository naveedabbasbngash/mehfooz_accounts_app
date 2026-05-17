// lib/ui/home/widgets/acc1_summary_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/currency_flag.dart';
import '../../commons/fade_slide.dart';

const _kHomeBrandBlue = Color(0xFF1862A3);

class Acc1SummaryCard extends StatelessWidget {
  final HomeViewModel vm;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int maxVisible;

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
    final rows = vm.acc1CashSummary.where((r) => r.amount != 0).toList();
    final hasData = rows.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: hasData ? _buildContent(rows) : _emptyState(),
    );
  }

  Column _buildContent(List<dynamic> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(),
        const SizedBox(height: 8),
        Divider(height: 16, color: AppColors.divider),
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
    );
  }

  String _countryNameForCurrency(String currency) =>
      currencyCountryName(currency);

  Row _titleRow() {
    return Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          color: _kHomeBrandBlue,
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          "Cash In Hand",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRows(List<dynamic> rows) {
    final visible = isExpanded
        ? rows.length
        : rows.length.clamp(0, maxVisible).toInt();

    return List.generate(visible, (i) {
      final row = rows[i];
      final isPositive = row.amount >= 0;
      final currency = (row.currency ?? '').toString().trim().isEmpty
          ? 'Unknown'
          : row.currency.toString().trim();
      final countryName = _countryNameForCurrency(currency);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CurrencyFlagBadge(currency: currency, size: 26),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      countryName,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _AnimatedMoneyText(
              value: row.amount.toDouble(),
              fmt: fmt,
              color: isPositive ? _kHomeBrandBlue : AppColors.error,
            ),
          ],
        ),
      );
    });
  }

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
              color: _kHomeBrandBlue,
            ),
            const SizedBox(width: 5),
            Text(
              isExpanded ? "Show less" : "+ $hiddenCount more",
              style: TextStyle(
                fontSize: 13,
                color: _kHomeBrandBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return FadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _kHomeBrandBlue.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kHomeBrandBlue.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kHomeBrandBlue.withValues(alpha: 0.10),
                border: Border.all(
                  color: _kHomeBrandBlue.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 28,
                color: _kHomeBrandBlue.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Cash Summary Yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF102132),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Cash balances will appear here once account activity starts flowing into the selected company.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

/// ----------------------------------------------------------------
/// Animated number — ONLY animates when VALUE changes
/// ----------------------------------------------------------------
class _AnimatedMoneyText extends StatefulWidget {
  final double value;
  final NumberFormat fmt;
  final Color color;

  const _AnimatedMoneyText({
    required this.value,
    required this.fmt,
    required this.color,
  });

  @override
  State<_AnimatedMoneyText> createState() => _AnimatedMoneyTextState();
}

class _AnimatedMoneyTextState extends State<_AnimatedMoneyText> {
  late double _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedMoneyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _oldValue, end: widget.value),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Text(
          widget.fmt.format(v),
          style: TextStyle(color: widget.color, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}

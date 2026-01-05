// lib/ui/home/widgets/acc1_summary_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../commons/fade_slide.dart';

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

  Row _titleRow() {
    return Row(
      children: [
        Icon(Icons.account_balance_wallet_outlined,
            color: AppColors.primary, size: 22),
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
    final visible =
    isExpanded ? rows.length : rows.length.clamp(0, maxVisible);

    return List.generate(visible, (i) {
      final row = rows[i];
      final isPositive = row.amount >= 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(row.currency,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            _AnimatedMoneyText(
              value: row.amount.toDouble(),
              fmt: fmt,
              color: isPositive ? AppColors.success : AppColors.error,
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
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
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

  Widget _emptyState() {
    return FadeSlide(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.wallet_outlined,
                size: 40, color: AppColors.primary.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text(
              "No Cash Summary Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
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
    super.key,
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
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        return Text(
          widget.fmt.format(v),
          style: TextStyle(
            color: widget.color,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}
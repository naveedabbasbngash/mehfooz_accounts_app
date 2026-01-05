// lib/ui/home/widgets/cash_in_hand_card.dart
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
    final rows =
    vm.cashInHandSummary.where((r) => r.amount != 0).toList();
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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
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

  Row _titleRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.money, color: AppColors.primary, size: 22),
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
              color:
              isPositive ? AppColors.primary : AppColors.error,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildExpandToggle(int hiddenCount) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
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
              "No Summary Yet",
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

void _exportCombinedPdf(BuildContext context, HomeViewModel vm) async {
  final companyName = vm.selectedCompanyName ?? "Mahfooz Accounts";

  final file = await SummaryCombinedPdfService.instance.render(
    companyName: companyName,
    jbRows: vm.cashInHandSummary,
    acc1Rows: vm.acc1CashSummary,
  );

  await OpenFilex.open(file.path);
}
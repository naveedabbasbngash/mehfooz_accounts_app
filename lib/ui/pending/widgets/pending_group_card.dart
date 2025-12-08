// lib/ui/pending/widgets/pending_group_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

import '../../../model/pending_group_row.dart';

class PendingGroupCard extends StatefulWidget {
  final PendingGroupRow row;
  final String highlight;

  // Selection mode
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPressToSelect;

  const PendingGroupCard({
    super.key,
    required this.row,
    this.highlight = "",
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.onLongPressToSelect,
  });

  @override
  State<PendingGroupCard> createState() => _PendingGroupCardState();
}

class _PendingGroupCardState extends State<PendingGroupCard> {
  bool expanded = true;

  final NumberFormat fmt = NumberFormat('#,##0.##');

  // ============================================================
  // Highlight text
  // ============================================================
  TextSpan _hl(String text, String q, TextStyle normal, TextStyle bold) {
    if (q.isEmpty) return TextSpan(text: text, style: normal);

    final lower = text.toLowerCase();
    final search = q.toLowerCase();
    final index = lower.indexOf(search);

    if (index == -1) return TextSpan(text: text, style: normal);

    return TextSpan(children: [
      TextSpan(text: text.substring(0, index), style: normal),
      TextSpan(text: text.substring(index, index + search.length), style: bold),
      TextSpan(text: text.substring(index + search.length), style: normal),
    ]);
  }

  // ============================================================
  // Small Tag (PD, Currency, etc.)
  // ============================================================
  Widget _smallTag(String text, String hl) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.highlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: RichText(
        text: _hl(
          text,
          hl,
          TextStyle(color: AppColors.textLight, fontSize: 12),
          TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Selection dot
  // ============================================================
  Widget _selectionDot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : AppColors.cardBackground,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: 2,
        ),
        boxShadow: selected
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ]
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final hl = widget.highlight.trim();
    final negative = row.balance < 0;

    return GestureDetector(
      onTap: () {
        if (widget.selectionMode) {
          widget.onSelectionToggle?.call();
        } else {
          setState(() => expanded = !expanded);
        }
      },
      onLongPress: () {
        widget.onLongPressToSelect?.call();
      },
      child: Stack(
        children: [
          // ================= CARD =====================
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: AppColors.divider),
            ),
            child: expanded
                ? _expandedView(row, negative, hl)
                : _collapsedView(row, negative, hl),
          ),

          // ================= SELECTION DOT =============
          if (widget.selectionMode)
            Positioned(
              top: 12,
              right: 12,
              child: _selectionDot(widget.isSelected),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // COLLAPSED VIEW
  // ============================================================
  Widget _collapsedView(PendingGroupRow r, bool isNeg, String hl) {
    final normal = TextStyle(color: AppColors.textDark, fontSize: 14);
    final bold = TextStyle(color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // DATE
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: _hl(r.beginDate, hl, normal, bold)),

                if (r.pd?.isNotEmpty ?? false)
                  _smallTag("PD: ${r.pd!}", hl),
              ],
            ),

            const Spacer(),

            // CURRENCY TAG
            if (r.accTypeName != null)
              _smallTag(r.accTypeName!, hl),

            const SizedBox(width: 12),

            // BALANCE
            Text(
              fmt.format(r.balance),
              style: TextStyle(
                color: isNeg ? AppColors.error : AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Text("S: ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight)),
            Expanded(child: RichText(text: _hl(r.sender ?? "—", hl, normal, bold))),
            const SizedBox(width: 16),
            Text("R: ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight)),
            Expanded(child: RichText(text: _hl(r.receiver ?? "—", hl, normal, bold))),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // EXPANDED VIEW
  // ============================================================
  Widget _expandedView(PendingGroupRow r, bool isNeg, String hl) {
    final normal = TextStyle(color: AppColors.textDark, fontSize: 14);
    final bold = TextStyle(color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TOP HEADER
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: _hl(r.beginDate, hl, bold, bold)),

                if (r.pd?.isNotEmpty ?? false)
                  _smallTag("PD: ${r.pd!}", hl),
              ],
            ),

            const Spacer(),

            if (r.accTypeName != null) _smallTag(r.accTypeName!, hl),

            const SizedBox(width: 12),

            Text(
              fmt.format(r.balance),
              style: TextStyle(
                color: isNeg ? AppColors.error : AppColors.textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        if (r.msgNo?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          RichText(
            text: _hl(
              "Msg: ${r.msgNo}",
              hl,
              TextStyle(color: AppColors.textMuted),
              TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        const SizedBox(height: 16),

        _infoLine("Sender", r.sender ?? "—", hl),
        const SizedBox(height: 8),
        _infoLine("Receiver", r.receiver ?? "—", hl),

        const SizedBox(height: 18),

        // ================= AMOUNT SUMMARY ====================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greyLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _amtPill("P.Amount", fmt.format(r.notPaidAmount)),
              _amtPill("Paid", fmt.format(r.paidAmount)),
              _amtPill("Balance", fmt.format(r.balance), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO TEXT
  // ============================================================
  Widget _infoLine(String label, String value, String hl) {
    return Row(
      children: [
        Text("$label: ",
            style: TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
            )),
        Expanded(
          child: RichText(
            text: _hl(
              value,
              hl,
              TextStyle(color: AppColors.textDark),
              TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AMOUNT PILL (P.Amount / Paid / Balance)
  // ============================================================
  Widget _amtPill(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: bold ? 18 : 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
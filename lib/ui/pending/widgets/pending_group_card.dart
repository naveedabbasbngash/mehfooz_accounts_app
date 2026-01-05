import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:country_flags/country_flags.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

import '../../../model/pending_group_row.dart';

class PendingGroupCard extends StatefulWidget {
  final PendingGroupRow row;
  final String highlight;

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

  // --------------------------------------------------------
  // Currency → Country Code Mapper
  // --------------------------------------------------------
  String _currencyToCountry(String currency) {
    switch (currency.toUpperCase().trim()) {
      case "PKR":
        return "PK";
      case "USD":
        return "US";
      case "AED":
        return "AE";
      case "SAR":
        return "SA";
      case "EUR":
        return "EU";
      case "GBP":
      case "POUND":
        return "GB";
      case "INR":
      case "IND":
        return "IN";
      case "AFG":
        return "AF";
      case "CAD":
        return "CA";
      case "JPY":
        return "JP";
      case "RMB":
        return "CN";
      default:
        return "UN";
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final isNeg = r.balance < 0;

    return GestureDetector(
      onTap: () {
        if (widget.selectionMode) {
          widget.onSelectionToggle?.call();
        } else {
          setState(() => expanded = !expanded);
        }
      },
      onLongPress: widget.onLongPressToSelect,
      child: AnimatedContainer(
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
            ? _expandedView(r, isNeg)
            : _collapsedView(r, isNeg),
      ),
    );
  }

  // ============================================================
  // COLLAPSED VIEW
  // ============================================================
  Widget _collapsedView(PendingGroupRow r, bool isNeg) {
    return Row(
      children: [
        Text(
          r.beginDate,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        const Spacer(),

        if (r.accTypeName != null)
          Row(
            children: [
              CountryFlag.fromCountryCode(
                _currencyToCountry(r.accTypeName!),
                theme: const ImageTheme(
                  width: 14,
                  height: 14,
                  shape: Circle(),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                r.accTypeName!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

        const SizedBox(width: 12),

        Text(
          fmt.format(r.balance),
          style: const TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EXPANDED VIEW
  // ============================================================
  Widget _expandedView(PendingGroupRow r, bool isNeg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================= HEADER =================
        Row(
          children: [
            Text(
              r.beginDate,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),

            if (r.accTypeName != null)
              Row(
                children: [
                  CountryFlag.fromCountryCode(
                    _currencyToCountry(r.accTypeName!),
                    theme: const ImageTheme(
                      width: 14,
                      height: 14,
                      shape: Circle(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.accTypeName!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

            const SizedBox(width: 12),

            Text(
              fmt.format(r.balance),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ================= SENDER / RECEIVER =================
        _infoLine("Sender", r.sender ?? "—"),
        const SizedBox(height: 8),
        _infoLine("Receiver", r.receiver ?? "—"),

        // ================= MSG NO (NEW) =================
        if (r.msgNo != null && r.msgNo!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _infoLine("Msg No", r.msgNo!),
        ],

        const SizedBox(height: 18),

        // ================= AMOUNT SUMMARY =================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.greyLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _amtPill("P.Amount", fmt.format(r.notPaidAmount)),
              _amtPill("Paid", fmt.format(r.paidAmount)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Balance",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(r.balance),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO LINE
  // ============================================================
  Widget _infoLine(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AMOUNT PILL
  // ============================================================
  Widget _amtPill(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
// lib/ui/transactions/widgets/tx_filter_chips.dart
import 'package:flutter/material.dart';
import '../../../model/tx_filter.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

class TxFilterChips extends StatelessWidget {
  final String search;
  final TxFilter filter;
  final String dateLabel;

  final VoidCallback onShowAll;
  final VoidCallback onShowDebits;
  final VoidCallback onShowCredits;
  final VoidCallback onShowDates;
  final VoidCallback onToggleBalance;

  final String? selectedCurrency;
  final List<String> currencies;
  final ValueChanged<String?> onCurrencySelect;

  const TxFilterChips({
    super.key,
    required this.search,
    required this.filter,
    required this.dateLabel,
    required this.onShowAll,
    required this.onShowDebits,
    required this.onShowCredits,
    required this.onShowDates,
    required this.onToggleBalance,
    required this.selectedCurrency,
    required this.currencies,
    required this.onCurrencySelect,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSearching = search.trim().isNotEmpty;
    final List<Widget> chips = [];

    // ALL
    chips.add(_chip(
      label: "All",
      selected: filter == TxFilter.all,
      onTap: onShowAll,
    ));

    // Currency chip only if searching
    if (isSearching) {
      chips.add(_currencyChip(context));
    }

    // Debits
    chips.add(_chip(
      label: "Debits",
      selected: filter == TxFilter.debit,
      onTap: onShowDebits,
    ));

    // Credits
    chips.add(_chip(
      label: "Credits",
      selected: filter == TxFilter.credit,
      onTap: onShowCredits,
    ));

    // Date Range
    chips.add(_chip(
      label: dateLabel,
      selected: filter == TxFilter.dateRange,
      onTap: onShowDates,
    ));

    // Balance (only when searching)
    if (isSearching) {
      chips.add(_chip(
        label: "Balance",
        selected: filter == TxFilter.balance,
        onTap: onToggleBalance,
      ));
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  // ==========================================================
  // CHIP UI (uses AppColors everywhere)
  // ==========================================================
// MAIN CHIP DESIGN (Updated: selected chip = white text + primary bg)
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? _kTxBrandBlue
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? _kTxBrandBlue
                : _kTxBrandBlue.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kTxBrandBlue.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF23415E),
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12.8,
            height: 1.0,
          ),
        ),
      ),
    );
  }
  // ==========================================================
  // CURRENCY DROPDOWN CHIP (Styled with AppColors)
  // ==========================================================
  Widget _currencyChip(BuildContext context) {
    final bool active = selectedCurrency != null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == "Clear") {
          onCurrencySelect(null);
        } else {
          onCurrencySelect(value);
        }
      },
      color: Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (_) {
        final list = <PopupMenuEntry<String>>[];

        // All currencies
        for (final cur in currencies) {
          list.add(
            PopupMenuItem(
              value: cur,
              child: Text(
                cur,
                style: const TextStyle(fontSize: 14, color: Color(0xFF16324B)),
              ),
            ),
          );
        }

        list.add(
          PopupMenuItem(
            value: "Clear",
            child: Text(
              "Clear",
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 14),
            ),
          ),
        );

        return list;
      },
      offset: const Offset(0, 34),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: active
              ? _kTxBrandBlue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? _kTxBrandBlue
                : _kTxBrandBlue.withValues(alpha: 0.14),
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCurrency ?? "Currency",
              style: TextStyle(
                color: active ? _kTxBrandBlue : const Color(0xFF71869B),
                fontWeight: FontWeight.w600,
                fontSize: 12.8,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: active ? _kTxBrandBlue : const Color(0xFF71869B),
            ),
          ],
        ),
      ),
    );
  }
}

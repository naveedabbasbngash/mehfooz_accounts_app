// lib/ui/transactions/widgets/tx_filter_chips.dart
import 'package:flutter/material.dart';
import '../../../model/tx_filter.dart';

class TxFilterChips extends StatelessWidget {
  final String search;
  final TxFilter filter;      // ACTIVE FILTER FROM VIEWMODEL
  final String dateLabel;     // 👈 NEW: pretty formatted label for Dates chip

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

    // ------------------------------------------------------
    // ALL
    // ------------------------------------------------------
    chips.add(_chip(
      label: "All",
      selected: filter == TxFilter.all,
      onTap: onShowAll,
    ));

    // ------------------------------------------------------
    // Currency dropdown only when user typed something
    // ------------------------------------------------------
    if (isSearching) {
      chips.add(_currencyChip(context));
    }

    // ------------------------------------------------------
    // Debits
    // ------------------------------------------------------
    chips.add(_chip(
      label: "Debits",
      selected: filter == TxFilter.debit,
      onTap: onShowDebits,
    ));

    // ------------------------------------------------------
    // Credits
    // ------------------------------------------------------
    chips.add(_chip(
      label: "Credits",
      selected: filter == TxFilter.credit,
      onTap: onShowCredits,
    ));

    // ------------------------------------------------------
    // Dates (NOW FIXED)
    // ------------------------------------------------------
    chips.add(_chip(
      label: dateLabel,                      // 👈 EXTERNAL LABEL
      selected: filter == TxFilter.dateRange,
      onTap: onShowDates,
    ));

    // ------------------------------------------------------
    // Balance (only when searching)
    // ------------------------------------------------------
    if (isSearching) {
      chips.add(_chip(
        label: "Balance",
        selected: filter == TxFilter.balance,
        onTap: onToggleBalance,
      ));
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  // ------------------------------------------------------
  // MAIN CHIP DESIGN
  // ------------------------------------------------------
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDEE1F8) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.transparent,
            width: 1.3,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.deepPurple : Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------
  // CURRENCY DROPDOWN CHIP
  // ------------------------------------------------------
  Widget _currencyChip(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == "Clear") {
          onCurrencySelect(null);
        } else {
          onCurrencySelect(value);
        }
      },
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) {
        final list = <PopupMenuEntry<String>>[];

        // All currencies
        for (final cur in currencies) {
          list.add(
            PopupMenuItem(
              value: cur,
              child: Text(
                cur,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          );
        }

        // Clear option
        list.add(
          const PopupMenuItem(
            value: "Clear",
            child: Text(
              "Clear",
              style: TextStyle(color: Colors.red),
            ),
          ),
        );

        return list;
      },
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selectedCurrency != null
                ? Colors.deepPurple
                : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Text(
              selectedCurrency ?? "Currency",
              style: TextStyle(
                color: selectedCurrency != null
                    ? Colors.deepPurple
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: selectedCurrency != null
                  ? Colors.deepPurple
                  : Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }
}
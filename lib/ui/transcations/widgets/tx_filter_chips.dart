// lib/ui/transactions/widgets/tx_filter_chips.dart
import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import '../../../model/tx_filter.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary                 // ← Full primary background
              : AppColors.highlight,              // ← Soft background
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textDark, // ← WHITE TEXT
            fontWeight: selected ? FontWeight.bold : FontWeight.w600, // ← BOLD
            fontSize: 13.5,
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
      color: AppColors.cardBackground,
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
                style: TextStyle(fontSize: 14, color: AppColors.textDark),
              ),
            ),
          );
        }

        list.add(
          PopupMenuItem(
            value: "Clear",
            child: Text(
              "Clear",
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        );

        return list;
      },
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.highlight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.divider,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Text(
              selectedCurrency ?? "Currency",
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: active ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
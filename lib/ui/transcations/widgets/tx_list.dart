import 'package:flutter/material.dart';
import '../../../model/tx_item_ui.dart';
import 'tx_list_row.dart';

const _kTxBrandBlue = Color(0xFF1862A3);

class TxList extends StatelessWidget {
  final List<TxItemUi> items;
  final Function(TxItemUi row) onRowTap;
  final Function(TxItemUi row)? onRowLongPress;
  final Set<int> selectedVoucherNos;

  const TxList({
    super.key,
    required this.items,
    required this.onRowTap,
    this.onRowLongPress,
    this.selectedVoucherNos = const <int>{},
  });

  String _ownerLabel(TxItemUi item) {
    final email = item.userEmail?.trim() ?? '';
    if (email.isNotEmpty) return email;
    if (item.userId != null) return 'User ${item.userId}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // --------------------------------------------------------------
    // Empty State
    // --------------------------------------------------------------
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kTxBrandBlue.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _kTxBrandBlue.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kTxBrandBlue.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: _kTxBrandBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "No transactions found",
                  style: TextStyle(
                    color: Color(0xFF16324B),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  "Try another search or add a new entry to start building your transaction history.",
                  style: TextStyle(
                    color: Color(0xFF6F8094),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // --------------------------------------------------------------
    // TRANSACTIONS LIST (Google Material Clean UI)
    // --------------------------------------------------------------
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        final isSelected = selectedVoucherNos.contains(item.voucherNo);
        final ownerLabel = _ownerLabel(item);
        final cardColor = isSelected
            ? _kTxBrandBlue.withValues(alpha: 0.06)
            : Colors.white;
        final cardBorderColor = isSelected
            ? _kTxBrandBlue.withValues(alpha: 0.45)
            : const Color(0xFFDDE8F2);
        final cardBorderWidth = isSelected ? 1.2 : 1.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorderColor, width: cardBorderWidth),
            boxShadow: [
              BoxShadow(
                color: const Color(0x141862A3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              TxListRow(
                item: item,
                onTap: () => onRowTap(item),
                onLongPress: onRowLongPress == null
                    ? null
                    : () => onRowLongPress!(item),
                isSelected: isSelected,
              ),
              if (ownerLabel.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kTxBrandBlue.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: _kTxBrandBlue.withValues(alpha: 0.18),
                            width: cardBorderWidth,
                          ),
                          bottom: BorderSide(
                            color: _kTxBrandBlue.withValues(alpha: 0.18),
                            width: cardBorderWidth,
                          ),
                        ),
                      ),
                      child: Text(
                        ownerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: const Color(0xFF5F7893),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

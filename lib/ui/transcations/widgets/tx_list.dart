import 'package:flutter/material.dart';
import '../../../model/tx_item_ui.dart';
import 'tx_list_row.dart';

class TxList extends StatelessWidget {
  final List<TxItemUi> items;
  final Function(TxItemUi row) onRowTap;

  const TxList({
    super.key,
    required this.items,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    // --------------------------------------------------------------
    // Empty State
    // --------------------------------------------------------------
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Text(
            "No transactions found",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // --------------------------------------------------------------
    // TRANSACTIONS LIST (Google Material Clean UI)
    // --------------------------------------------------------------
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.shade50,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          child: TxListRow(
            item: item,
            onTap: () => onRowTap(item),
          ),
        );
      },
    );
  }
}
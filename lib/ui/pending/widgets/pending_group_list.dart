import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/ui/pending/widgets/pending_group_card.dart';
import '../../../model/pending_group_row.dart';
import '../pending_grouped_screen.dart';

class PendingGroupList extends StatelessWidget {
  final List<PendingGroupRow> rows;

  const PendingGroupList({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          "No Pending Amount found",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        return PendingGroupCard(row: rows[index]);
      },
    );
  }
}
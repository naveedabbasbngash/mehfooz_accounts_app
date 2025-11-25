import 'package:flutter/material.dart';
import '../../../data/local/database_manager.dart';
import '../../../viewmodel/home/home_view_model.dart';

class HomeHeader extends StatelessWidget {
  final HomeViewModel vm;
  final VoidCallback onChangeCompany;

  const HomeHeader({
    super.key,
    required this.vm,
    required this.onChangeCompany,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getCompanyName(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? "Mahfooz Accounts";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Change Company Chip
            TextButton.icon(
              style: TextButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onChangeCompany,
              icon: const Icon(
                Icons.swap_horiz,
                size: 18,
                color: Colors.deepPurple,
              ),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Change company",
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _getCompanyName() async {
    final selectedId = vm.selectedCompanyId;
    if (selectedId == null) return null;

    final db = DatabaseManager.instance.db;

    final result = await (db.select(db.companyTable)
      ..where((tbl) => tbl.companyId.equals(selectedId)))
        .get();

    if (result.isNotEmpty) {
      return result.first.companyName ?? "Your Company";
    }

    return "Your Company";
  }
}
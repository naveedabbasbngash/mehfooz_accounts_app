import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/local/database_manager.dart';
import '../../../viewmodel/home/home_view_model.dart';

class CompanySelectorBottomSheet {
  /// -------------------------------------------------------------
  /// SHOW BOTTOM SHEET
  /// -------------------------------------------------------------
  static Future<void> show(BuildContext context, HomeViewModel vm) async {
    final db = DatabaseManager.instance.db;
    final companies = await db.select(db.companyTable).get();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                const Text(
                  "Select company",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: companies.length,
                    itemBuilder: (context, index) {
                      final c = companies[index];
                      final isSelected =
                          vm.selectedCompanyId == c.companyId;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.deepPurple.shade50,
                          child: const Icon(
                            Icons.business,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: Text(
                          c.companyName ?? "Unnamed company",
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          if (c.companyId != null) {
                            vm.selectCompany(c.companyId!);
                            vm.loadPendingAmounts();
                          }
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

class PendingSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const PendingSearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(color: AppColors.textDark),

        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: AppColors.primary),

          hintText: "Search pending entries...",
          hintStyle: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),

          filled: true,
          fillColor: AppColors.cardBackground,   // ← consistent with cards

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.divider), // ← NEW
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.divider), // ← NEW
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.primary,          // ← NEW Highlight
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'confirm_action.dart';

class ConfirmActionDialog extends StatelessWidget {
  final ConfirmAction action;

  const ConfirmActionDialog({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        action.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      content: Text(
        action.message,
        style: TextStyle(color: AppColors.textDark),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: () {
            Navigator.pop(context);
            action.onConfirm();
          },
          child: Text(action.confirmText),
        ),
      ],
    );
  }
}
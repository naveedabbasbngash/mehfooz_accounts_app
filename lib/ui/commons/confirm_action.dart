
import 'dart:ui';

enum ConfirmActionType {
  importLocalDb,
  manualSync,
  emailMismatch,
}

class ConfirmAction {
  final ConfirmActionType type;
  final String title;
  final String message;
  final String confirmText;
  final VoidCallback onConfirm;

  ConfirmAction({
    required this.type,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.onConfirm,
  });
}
import 'package:flutter/material.dart';

import '../../../viewmodel/sync/sync_viewmodel.dart';
import '../../commons/fade_slide.dart';

class LastSyncSummaryCard extends StatelessWidget {
  final SyncViewModel vm;

  const LastSyncSummaryCard({
    super.key,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    // If no message and not syncing → hide card
    if (vm.lastMessage.isEmpty && !vm.isSyncing) {
      return const SizedBox.shrink();
    }

    final bool isError = vm.lastMessage.startsWith("❌");
    final Color bgColor =
    isError ? Colors.red.shade50 : Colors.green.shade50;
    final Color borderColor =
    isError ? Colors.red.shade200 : Colors.green.shade300;
    final Color iconColor =
    isError ? Colors.red.shade700 : Colors.green.shade700;
    final IconData icon =
    isError ? Icons.error_outline : Icons.check_circle_outline;

    return FadeSlide(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Last Sync",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vm.lastMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right side: spinner or small label
            if (vm.isSyncing)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                "Synced",
                style: TextStyle(
                  fontSize: 12,
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
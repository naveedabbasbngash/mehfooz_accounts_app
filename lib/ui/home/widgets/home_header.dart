import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mehfooz_accounts_app/services/logging/logger_service.dart';
import 'package:provider/provider.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';

import '../../../data/local/database_manager.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/sync/sync_viewmodel.dart';
import 'google_sync_icon.dart';

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
        final companyName = snapshot.data ?? "Mahfooz Accounts";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeft(context, companyName)),
                const SizedBox(width: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    LoggerService.debug(
                      "Header constraints → maxWidth=${constraints.maxWidth}",
                    );
                    return _buildSyncButton(context);
                  },
                ),              ],
            ),

            const SizedBox(height: 6),
            _buildLastSynced(context),

            // ✅ Auto Sync toggle
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LEFT SIDE (Welcome + Company)
  // ─────────────────────────────────────────────────────────────
  Widget _buildLeft(BuildContext context, String companyName) {
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
          companyName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onChangeCompany,
          icon: const Icon(
            Icons.swap_horiz,
            size: 18,
            color: AppColors.primary,
          ),
          label: const Text(
            "Change company",
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MORPHING SYNC BUTTON (Google-style)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSyncButton(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        final syncing = svm.isSyncing;
        final isError = svm.lastMessage.startsWith("❌");
        final expanded = syncing || isError;

        LoggerService.debug(
          "SyncButton → syncing=$syncing | error=$isError | expanded=$expanded | "
              "message='${svm.lastMessage}'",
        );

        String label = "Synced";
        Color labelColor = Colors.green;

        if (syncing) {
          label = "Syncing…";
          labelColor = Colors.blue;
        } else if (isError) {
          label = "Error";
          labelColor = Colors.red;
        }

        LoggerService.debug(
            "SyncButton label='$label' (len=${label.length})");

        return GestureDetector(
          onTap: syncing ? null : () {
            LoggerService.debug(
                "SyncButton tapped");
            svm.syncNow();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: expanded ? 140 : 42,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: expanded
                    ? Row(
                  key: const ValueKey("expanded"),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GoogleStyleSyncIcon(
                      syncing: syncing,
                      success: !syncing && !isError,
                      error: isError,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ],
                )
                    : Center(
                  key: const ValueKey("compact"),
                  child: GoogleStyleSyncIcon(
                    syncing: syncing,
                    success: !syncing && !isError,
                    error: isError,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  // ─────────────────────────────────────────────────────────────
  // LAST SYNC / STATUS LINE
  // ─────────────────────────────────────────────────────────────
  Widget _buildLastSynced(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        String text;
        Color color = Colors.grey.shade600;
        IconData icon = Icons.access_time;

        if (svm.isSyncing ||
            (svm.lastMessage.isNotEmpty &&
                !svm.lastMessage.startsWith("✔"))) {
          text = svm.lastMessage;
          color = Colors.blue.shade700;
          icon = Icons.sync;
        } else if (svm.lastMessage.startsWith("❌")) {
          text = svm.lastMessage;
          color = Colors.red.shade700;
          icon = Icons.error;
        } else if (svm.lastSyncedTime != null) {
          final diff = DateTime.now().difference(svm.lastSyncedTime!);
          text = "Last synced • ${_friendly(diff)}";
        } else {
          text = "Not synced yet";
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Row(
            key: ValueKey(text),
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AUTO SYNC TOGGLE
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  String _friendly(Duration d) {
    if (d.inSeconds < 60) return "just now";
    if (d.inMinutes < 60) return "${d.inMinutes} min ago";
    if (d.inHours < 24) return "${d.inHours} hrs ago";
    return "${d.inDays} days ago";
  }

  Future<String?> _getCompanyName() async {
    final id = vm.selectedCompanyId;
    if (id == null) return null;

    final db = DatabaseManager.instance.db;
    final rows = await (db.select(db.companyTable)
      ..where((tbl) => tbl.companyId.equals(id)))
        .get();

    return rows.isNotEmpty ? rows.first.companyName : "Your Company";
  }
}
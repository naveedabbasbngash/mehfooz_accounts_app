import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import 'package:provider/provider.dart';

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
        final name = snapshot.data ?? "Mahfooz Accounts";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeft(context, name)),
                const SizedBox(width: 8),
                _buildSyncButton(context),
              ],
            ),

            const SizedBox(height: 6),
            _buildLastSynced(context),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // LEFT SIDE
  // -------------------------------------------------------------------------
  Widget _buildLeft(BuildContext context, String name) {
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
        )
      ],
    );
  }

  // -------------------------------------------------------------------------
  // RIGHT SIDE — Morphing Sync Capsule (icon-only ↔ icon+text)
  // -------------------------------------------------------------------------
  Widget _buildSyncButton(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        final bool syncing = svm.isSyncing;
        final bool isError = svm.lastMessage.startsWith("❌");

        // When should the capsule be expanded with text?
        final bool expanded = syncing || isError;

        // Decide label + color for expanded state
        String label = "Synced";
        Color labelColor = Colors.green;

        if (syncing) {
          label = "Syncing...";
          labelColor = Colors.blue;
        } else if (isError) {
          label = "Error";
          labelColor = Colors.red;
        }

        return GestureDetector(
          onTap: syncing ? null : () => svm.syncNow(),
          onLongPress: () => _openSettings(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: expanded ? 140 : 40, // 🔥 morphing width
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: expanded
                  ? Row(
                key: const ValueKey('expanded'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Google-style animated sync icon
                  GoogleStyleSyncIcon(
                    syncing: syncing,
                    success: (!syncing && !isError),
                    error: isError,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
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
                key: const ValueKey('compact'),
                child: GoogleStyleSyncIcon(
                  syncing: syncing,
                  success: (!syncing && !isError),
                  error: isError,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // LAST SYNCED ROW
  // -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// LAST SYNCED OR PROGRESS MESSAGE
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// LAST SYNCED OR PROGRESS MESSAGE — WITH ANIMATION
// -------------------------------------------------------------------------
  Widget _buildLastSynced(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        String display;

        Color color = Colors.grey.shade600;
        IconData icon = Icons.access_time;

        // -------------------------------
        // 1️⃣ During Syncing OR Progress
        // -------------------------------
        if (svm.isSyncing ||
            (svm.lastMessage.isNotEmpty && !svm.lastMessage.startsWith("✔"))) {
          display = svm.lastMessage;
          color = Colors.blue.shade700;
          icon = Icons.sync;
        }

        // -------------------------------
        // 2️⃣ Error
        // -------------------------------
        else if (svm.lastMessage.startsWith("❌")) {
          display = svm.lastMessage;
          color = Colors.red.shade700;
          icon = Icons.error;
        }

        // -------------------------------
        // 3️⃣ Normal Last Synced Time
        // -------------------------------
        else if (svm.lastSyncedTime != null) {
          final diff = DateTime.now().difference(svm.lastSyncedTime!);
          display = "Last synced • ${_friendly(diff)}";
          color = Colors.grey.shade600;
          icon = Icons.access_time;
        }

        // -------------------------------
        // 4️⃣ Default
        // -------------------------------
        else {
          display = "Not synced yet";
          color = Colors.grey.shade500;
          icon = Icons.access_time;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutQuad,
              )),
              child: FadeTransition(
                opacity: anim,
                child: child,
              ),
            );
          },
          child: Row(
            key: ValueKey(display), // important for animation
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  String _friendly(Duration d) {
    if (d.inSeconds < 60) return "just now";
    if (d.inMinutes < 60) return "${d.inMinutes} min ago";
    if (d.inHours < 24) return "${d.inHours} hrs ago";
    return "${d.inDays} days ago";
  }

  // -------------------------------------------------------------------------
  // SETTINGS BOTTOM SHEET
  // -------------------------------------------------------------------------
  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _settingsSheet(context),
    );
  }

  Widget _settingsSheet(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: const [
                  Icon(Icons.settings, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text(
                    "Sync Settings",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 🔮 Future-ready: here you can later inject custom interval text
              SwitchListTile(
                value: svm.autoSync,
                title: const Text("Auto Sync (every 5 mins)"),
                onChanged: (v) => svm.setAutoSync(v),
              ),

              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("View Sync History"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _openHistory(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // SYNC HISTORY BOTTOM SHEET
  // -------------------------------------------------------------------------
  void _openHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _historySheet(context),
    );
  }

  Widget _historySheet(BuildContext context) {
    return Consumer<SyncViewModel>(
      builder: (context, svm, _) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: const [
                  Icon(Icons.history, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text(
                    "Sync History",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              svm.history.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  "No sync history yet",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
                  : SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: svm.history.length,
                  itemBuilder: (context, i) {
                    final item = svm.history[i];
                    return ListTile(
                      leading: Icon(
                        item.success
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                        item.success ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        item.message,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        item.timestamp.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  Future<String?> _getCompanyName() async {
    final id = vm.selectedCompanyId;
    if (id == null) return null;

    final db = DatabaseManager.instance.db;
    final rows = await (db.select(db.companyTable)
      ..where((tbl) => tbl.companyId.equals(id)))
        .get();

    if (rows.isNotEmpty) return rows.first.companyName;
    return "Your Company";
  }
}
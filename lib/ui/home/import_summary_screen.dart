// lib/ui/import/import_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/user_model.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/sync/sync_viewmodel.dart';
import '../../viewmodel/import/import_summary_view_model.dart';
import '../../services/file_picker_service.dart';
import '../../services/sqlite_import_service.dart';

class ImportSummaryScreen extends StatefulWidget {
  final String filePath;
  final UserModel user;

  const ImportSummaryScreen({
    super.key,
    required this.filePath,
    required this.user,
  });

  @override
  State<ImportSummaryScreen> createState() => _ImportSummaryScreenState();
}

class _ImportSummaryScreenState extends State<ImportSummaryScreen>
    with SingleTickerProviderStateMixin {
  bool expandCompanies = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ImportSummaryViewModel(filePath: widget.filePath, user: widget.user),
      child: Consumer2<ImportSummaryViewModel, SyncViewModel>(
        builder: (_, vm, svm, __) {
          if (vm.isLoading) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            backgroundColor: AppColors.app_bg,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: AppColors.primary,
              title: const Text(
                "Import Summary",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ============================================================
                  // USER HEADER CARD
                  // ============================================================
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundImage: widget.user.imageUrl.isNotEmpty
                                ? NetworkImage(widget.user.imageUrl)
                                : null,
                            child: widget.user.imageUrl.isEmpty
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.fullName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                    AppColors.textDark.withOpacity(0.65),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Imported file:\n${widget.filePath}",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                    AppColors.textDark.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ============================================================
                  // SYNC STATUS BAR
                  // ============================================================
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: svm.isSyncing ? 5 : 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.9),
                          AppColors.darkgreen.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),

                  // ============================================================
                  // SYNC BUTTON
                  // ============================================================
                  _syncButton(context, svm),

                  const SizedBox(height: 12),

                  // ============================================================
                  // IMPORT BUTTON
                  // ============================================================
                  _importButton(context),

                  const SizedBox(height: 20),

                  // ============================================================
                  // COMPANY SELECTOR (PROFILE-STYLE + POLISHED)
                  // ============================================================
                  _companySelectorAnimated(context, vm),

                  const SizedBox(height: 18),

                  // ============================================================
                  // PLAN CARDS
                  // ============================================================
                  _planCards(widget.user),

                  const SizedBox(height: 18),

                  // ============================================================
                  // DB INFO
                  // ============================================================
                  _dbInfoCard(vm),

                  const SizedBox(height: 12),

                  // ============================================================
                  // EMAIL MATCH CARD
                  // ============================================================
                  _emailMatchCard(vm, widget.user),

                  const SizedBox(height: 20),

                  // ============================================================
                  // TABLE LIST
                  // ============================================================
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "📁 Tables Found",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (vm.tables.isEmpty)
                            Text(
                              "No tables detected in this database.",
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                AppColors.textDark.withOpacity(0.6),
                              ),
                            )
                          else
                            ...vm.tables.map(
                                  (t) => Container(
                                margin:
                                const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.app_bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.table_chart,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================================================================
  // SYNC BUTTON (white text, full width)
  // ===================================================================
  Widget _syncButton(BuildContext context, SyncViewModel svm) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.sync, color: Colors.white),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: () async {
          await svm.syncNow();
          _showToast(context, svm.lastMessage);
        },
        label: const Text(
          "Sync Now",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // IMPORT BUTTON
  // ===================================================================
  Widget _importButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.file_open),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.darkgreen, width: 1.4),
          foregroundColor: AppColors.darkgreen,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final path = await FilePickerService.pickSqliteFile();
          if (path == null) {
            _showToast(context, "No file selected");
            return;
          }

          await SqliteImportService.importAndSaveDb(path);
          _showToast(context, "Database imported successfully!");
        },
        label: const Text(
          "Import Local Database",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // COMPANY SELECTOR (PROFILE-LIKE, GLOBAL BEHAVIOR VIA VM)
  // ===================================================================
  Widget _companySelectorAnimated(
      BuildContext context, ImportSummaryViewModel vm) {
    final selected = vm.selectedCompany;

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Company",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),

            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => expandCompanies = !expandCompanies),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.darkgreen, width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.business,
                        color: AppColors.darkgreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected?.companyName ?? "Select Company",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandCompanies ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 26,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: expandCompanies
                  ? Column(
                children: [
                  const SizedBox(height: 8),
                  ...vm.companies.map((company) {
                    final isSelected =
                        company.companyId == selected?.companyId;
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8),
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        title: Text(
                          company.companyName ?? "Unnamed",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          vm.selectCompany(company.companyId);
                          setState(() => expandCompanies = false);
                        },
                      ),
                    );
                  }).toList(),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // PLAN CARDS
  // ===================================================================
  Widget _planCards(UserModel user) {
    final List<Widget> cards = [];

    if (user.planStatus != null) {
      cards.add(
        Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading:
            const Icon(Icons.workspace_premium, color: Colors.blue),
            title: const Text(
              "Plan Status",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(user.planStatus!.statusText),
          ),
        ),
      );
    }

    if (user.expiry != null) {
      cards.add(
        Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.timer, color: Colors.orange),
            title: const Text(
              "Remaining Days",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text("${user.expiry!.remainingDays} days"),
          ),
        ),
      );
    }

    if (user.subscription != null) {
      cards.add(
        Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading:
            const Icon(Icons.calendar_month, color: Colors.green),
            title: const Text(
              "Subscription",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(user.subscription!.planTitle),
          ),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: c,
        )),
      ],
    );
  }

  // ===================================================================
  // DB INFO CARD
  // ===================================================================
  Widget _dbInfoCard(ImportSummaryViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(Icons.storage, color: AppColors.primary),
        title: const Text(
          "Database Info",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "Email: ${vm.dbEmail ?? "-"}\n"
              "Name : ${vm.dbName ?? "-"}",
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  // ===================================================================
  // EMAIL MATCH CARD
  // ===================================================================
  Widget _emailMatchCard(ImportSummaryViewModel vm, UserModel user) {
    final match = vm.emailMatch;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: match ? Colors.green.shade50 : Colors.red.shade50,
      child: ListTile(
        leading: Icon(
          match ? Icons.verified : Icons.error_outline,
          size: 30,
          color: match ? Colors.green : Colors.red,
        ),
        title: const Text(
          "Database Email Check",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          match
              ? "✔ Email matches with Db_Info"
              : "❌ Email does NOT match database",
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  // ===================================================================
  // TOAST
  // ===================================================================
  void _showToast(BuildContext context, String message) {
    if (message.isEmpty) return;

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
      message.startsWith("❌") ? AppColors.error : AppColors.success,
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
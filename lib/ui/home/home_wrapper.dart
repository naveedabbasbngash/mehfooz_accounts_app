import 'dart:async';
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../model/user_model.dart';
import '../../data/local/database_manager.dart';
import '../../repository/transactions_repository.dart';
import '../../services/global_state.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sync/pending_share.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/profile/profile_view_model.dart';

import '../../viewmodel/sync/sync_viewmodel.dart';
import '../accounts/accounts_screen.dart';
import '../chart_of_accounts/chart_of_accounts_screen.dart';
import '../compliance/compliance_center_screen.dart';
import '../currencies/currencies_screen.dart';
import '../drawer/drawer_menu.dart';
import '../heads/heads_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports.dart';
import '../subscription/subscription_status_card.dart';
import '../accounts/account_trash_screen.dart';
import '../transcations/transaction_screen.dart';
import '../transcations/transaction_trash_screen.dart';
import 'home_screen.dart';

import '../../services/logging/logger_service.dart';

const _kNavBrandBlue = Color(0xFF1862A3);

class HomeWrapper extends StatefulWidget {
  final UserModel user;
  final GlobalKey<SliderDrawerState> sliderDrawerKey;
  final int initialTabIndex;
  final Future<Null> Function()? onLogoutReset;

  const HomeWrapper({
    super.key,
    required this.user,
    required this.sliderDrawerKey,
    required this.initialTabIndex,
    this.onLogoutReset,
  });

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  static const int _homeIndex = 0;
  static const int _transactionIndex = 1;
  static const int _reportsIndex = 2;
  static const int _profileIndex = 3;
  static const int _currenciesIndex = 4;
  static const int _accountsIndex = 5;
  static const int _headsIndex = 6;
  static const int _chartOfAccountsIndex = 7;
  static const int _complianceIndex = 8;

  StreamSubscription<List<SharedMediaFile>>? _intentStream;

  late int _pageIndex = widget.initialTabIndex;
  bool _initDone = false;
  DateTime? _lastBackPressedAt;

  final List<String> _titles = [
    "Home",
    "Transaction",
    "Reports",
    "Profile",
    "Currencies",
    "Accounts",
    "Heads",
    "Chart of Accounts",
    "Compliance",
  ];

  final List<Widget> _screens = const [
    HomeScreenContent(),
    TransactionScreen(),
    ReportsScreen(),
    ProfileScreen(),
    CurrenciesScreen(),
    AccountsScreen(),
    HeadsScreen(),
    ChartOfAccountsScreen(),
    ComplianceCenterScreen(),
  ];

  @override
  void initState() {
    super.initState();

    const channel = MethodChannel('icloud_file_access');

    channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        final rawPath = call.arguments as String;

        debugPrint("📥 Flutter received path: $rawPath");

        await _handleImportPath(rawPath);
      }
    });

    // Android share flow (stream + cold-start payload)
    _listenToSharedFiles();
    _handleInitialSharedFile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initDone) return;
    _initDone = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final homeVM = context.read<HomeViewModel>();
      final profileVM = context.read<ProfileViewModel>();
      final syncVM = context.read<SyncViewModel>();

      // 🔗 CONNECT ACTIVATION → PROFILE
      syncVM.onActivationChanged = () async {
        await profileVM.refresh();
      };

      await homeVM.init(user: widget.user);
      await profileVM.refresh();

      // 🔥 HANDLE iOS OPEN-IN FILE (THE IMPORTANT PART)
      final pendingPath = PendingShare.path;
      if (pendingPath != null) {
        debugPrint("📥 Processing pending Open-In file: $pendingPath");

        await _handleImportPath(pendingPath);

        PendingShare.clear();
      }

      if (profileVM.isRestricted && mounted) {
        setState(() => _pageIndex = _profileIndex);
      }
    });
  }

  @override
  void dispose() {
    LoggerService.info("🏠 HomeWrapper.dispose()");
    _intentStream?.cancel();
    super.dispose();
  }

  void routeLog(String msg) {
    debugPrint("🧭 [HOME_WRAPPER] $msg");
  }

  // ============================================================
  // ANDROID SHARE INTENT
  // ============================================================
  // ============================================================
  // SHARE / OPEN-IN (Android + iOS)
  // ============================================================
  void _listenToSharedFiles() {
    routeLog("_listenToSharedFiles() platform=${Platform.operatingSystem}");

    _intentStream = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) async {
        routeLog("getMediaStream() files=${files.length}");

        if (files.isNotEmpty) {
          final path = files.first.path;
          routeLog("Shared file path=$path");

          if (path.isNotEmpty) {
            await _handleImportPath(path);
          }
        }

        // Important: reset after handling
        await ReceiveSharingIntent.instance.reset();
      },
      onError: (e) {
        routeLog("getMediaStream() ERROR: $e");
      },
    );
  }

  Future<void> _handleInitialSharedFile() async {
    try {
      final initialFiles = await ReceiveSharingIntent.instance
          .getInitialMedia();
      routeLog("getInitialMedia() files=${initialFiles.length}");

      if (initialFiles.isNotEmpty) {
        final path = initialFiles.first.path;
        routeLog("Initial shared file path=$path");

        if (path.isNotEmpty) {
          await _handleImportPath(path);
        }
      }

      await ReceiveSharingIntent.instance.reset();
    } catch (e) {
      routeLog("getInitialMedia() ERROR: $e");
    }
  }

  // ============================================================
  // IMPORT HANDLER
  // ============================================================
  Future<void> _handleImportPath(String rawPath) async {
    debugPrint("🚀 _handleImportPath()");
    debugPrint("📦 Raw path: $rawPath");

    // 🔥 CRITICAL FIX: handle iOS file:// URLs correctly
    String path;
    try {
      final uri = Uri.parse(rawPath);
      path = uri.toFilePath(); // <-- THIS FIXES Mobile Documents issue
    } catch (e) {
      debugPrint("❌ URI parse failed, using raw path");
      path = rawPath.replaceFirst("file://", "");
    }

    debugPrint("📄 Clean path: $path");
    debugPrint("📄 Exists: ${File(path).existsSync()}");

    if (!File(path).existsSync()) {
      _showErrorSafe("File not found. iCloud file not accessible.");
      return;
    }

    if (!path.toLowerCase().endsWith('.sqlite') &&
        !path.toLowerCase().endsWith('.db')) {
      _showErrorSafe("Only .sqlite or .db files allowed");
      return;
    }

    final savedPath = await SqliteImportService.importAndSaveDb(path);
    debugPrint("💾 Saved internal path: $savedPath");

    if (savedPath == null) {
      _showErrorSafe("Import failed");
      return;
    }

    if (!mounted) return;
    final homeVM = context.read<HomeViewModel>();
    final profileVM = context.read<ProfileViewModel>();

    // ignore: use_build_context_synchronously
    await homeVM.confirmAndImportDatabase(
      context: context,
      inputPath: savedPath,
      user: widget.user,
    );

    await profileVM.refresh();

    if (mounted) {
      setState(() => _pageIndex = _profileIndex);
    }
  }

  void _showErrorSafe(String msg) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Safer than dialog during startup:
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

      // If you MUST use dialog, do it here (post-frame):
      // showDialog(...);
    });
  }

  // ============================================================
  // DRAWER ITEM CLICK (FIX-1 APPLIED)
  // ============================================================
  void _onDrawerItemClick(int index) {
    widget.sliderDrawerKey.currentState?.closeSlider();
    _selectPage(index);
  }

  void _selectPage(int index) {
    if (_pageIndex == index) return;

    final profileVM = context.read<ProfileViewModel>();
    if (_isBlockedByRestriction(index, profileVM)) {
      setState(() => _pageIndex = _profileIndex);
      _showRestrictedAccessSheet(profileVM);
      return;
    }

    setState(() => _pageIndex = index);
  }

  bool _isBlockedByRestriction(int index, ProfileViewModel profileVM) {
    if (index == _profileIndex) return false;
    return profileVM.isRestricted || profileVM.isSubscriptionExpired;
  }

  void _showRestrictedAccessSheet(ProfileViewModel profileVM) {
    final user = profileVM.loggedInUser;
    final title = profileVM.isSubscriptionExpired
        ? 'Package renewal required'
        : 'Profile action required';
    final message = profileVM.isSubscriptionExpired
        ? 'Your package has expired. Profile remains available so you can review status and renew access.'
        : 'Import or restore your local database from Profile before using this section.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF12304F),
          content: Text(message),
        ),
      );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFC45A11),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102132),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SubscriptionStatusCard(user: user),
              const SizedBox(height: 14),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF52677D),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kNavBrandBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Review Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _handleBackPress() async {
    final drawerState = widget.sliderDrawerKey.currentState;
    final isDrawerOpen = drawerState?.isDrawerOpen ?? false;
    if (isDrawerOpen) {
      drawerState?.closeSlider();
      return false;
    }

    if (_pageIndex != _homeIndex) {
      setState(() => _pageIndex = _homeIndex);
      return false;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    if (shouldExit) {
      return true;
    }

    _lastBackPressedAt = now;
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            backgroundColor: _kNavBrandBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    return false;
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final visiblePageIndex = _isBlockedByRestriction(_pageIndex, profileVM)
        ? _profileIndex
        : _pageIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBackPress();
        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.app_bg,
        body: SafeArea(
          child: SliderDrawer(
            key: widget.sliderDrawerKey,
            isDraggable: false,
            sliderOpenSize: 240,
            appBar: SliderAppBar(
              config: SliderAppBarConfig(
                backgroundColor: _appBarColorFor(visiblePageIndex),
                title: Text(
                  _titles[visiblePageIndex],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: _buildTopRightMenu(context, visiblePageIndex),
              ),
            ),
            slider: DrawerMenu(
              currentPageIndex: visiblePageIndex,
              drawerKey: widget.sliderDrawerKey,
              onItemClick: _onDrawerItemClick, // ✅ FIX-1
              user: widget.user,
            ),
            child: _screens[visiblePageIndex],
          ),
        ),
        bottomNavigationBar: visiblePageIndex > _profileIndex
            ? null
            : SafeArea(
                child: CurvedNavigationBar(
                  index: visiblePageIndex,
                  height: 60,
                  backgroundColor: Colors.transparent,
                  color: _kNavBrandBlue,
                  buttonBackgroundColor: _kNavBrandBlue,
                  items: const [
                    Icon(Icons.home, color: Colors.white),
                    Icon(Icons.search, color: Colors.white),
                    Icon(Icons.bar_chart, color: Colors.white),
                    Icon(Icons.person, color: Colors.white),
                  ],
                  onTap: _selectPage,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Color _appBarColorFor(int pageIndex) {
    switch (pageIndex) {
      case _homeIndex:
        return AppColors.homeColor;
      case _transactionIndex:
        return AppColors.searchColor;
      case _reportsIndex:
        return AppColors.reportsColor;
      case _currenciesIndex:
      case _accountsIndex:
      case _headsIndex:
      case _chartOfAccountsIndex:
      case _complianceIndex:
        return AppColors.searchColor;
      default:
        return AppColors.profileColor;
    }
  }

  Widget? _buildTopRightMenu(BuildContext context, int pageIndex) {
    if (pageIndex == _transactionIndex) {
      return PopupMenuButton<String>(
        tooltip: 'More options',
        onSelected: (value) {
          if (value == 'trash') {
            final homeVM = context.read<HomeViewModel>();
            final companyId =
                homeVM.selectedCompanyId ?? GlobalState.instance.companyId;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionTrashScreen(
                  repo: TransactionsRepository(DatabaseManager.instance.db),
                  companyId: companyId,
                ),
              ),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'trash',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: _kNavBrandBlue),
              title: Text('Trash'),
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert, color: _kNavBrandBlue),
      );
    }

    if (pageIndex == _accountsIndex) {
      return PopupMenuButton<String>(
        tooltip: 'More options',
        onSelected: (value) {
          if (value == 'trash') {
            final companyId = context.read<HomeViewModel>().selectedCompanyId;
            if (companyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a company first.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountTrashScreen(companyId: companyId),
              ),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'trash',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: _kNavBrandBlue),
              title: Text('Trash'),
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert, color: _kNavBrandBlue),
      );
    }

    return null;
  }
}

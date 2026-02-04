import 'dart:async';
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../main.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/sqlite_import_service.dart';
import '../../services/sync/pending_share.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/profile/profile_view_model.dart';

import '../../viewmodel/sync/sync_viewmodel.dart';
import '../drawer/drawer_menu.dart';
import '../profile/profile_screen.dart';
import '../reports/reports.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_wrapper.dart';
import '../transcations/transaction_screen.dart';
import 'home_screen.dart';

import '../../services/logging/logger_service.dart';

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
  StreamSubscription<List<SharedMediaFile>>? _intentStream;

  late int _pageIndex = widget.initialTabIndex;
  bool _initDone = false;

  final List<String> _titles = [
    "Home",
    "Transaction",
    "Reports",
    "Profile",
  ];

  final List<Widget> _screens = const [
    HomeScreenContent(),
    TransactionScreen(),
    ReportsScreen(),
    ProfileScreen(),
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
        setState(() => _pageIndex = 3);
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
      final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
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

    await context.read<HomeViewModel>().confirmAndImportDatabase(
      context: context,
      inputPath: savedPath,
      user: widget.user,
    );

    await context.read<ProfileViewModel>().refresh();

    if (mounted) {
      setState(() => _pageIndex = 3);
    }
  }
  void _showErrorSafe(String msg) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Safer than dialog during startup:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );

      // If you MUST use dialog, do it here (post-frame):
      // showDialog(...);
    });
  }
  // ============================================================
  // iOS IMPORT
  // ============================================================
  Future<void> _importForIOS() async {
    final path = await FilePickerService.pickSqliteFile();
    if (path == null) return;

    await context.read<HomeViewModel>().confirmAndImportDatabase(
      context: context,
      inputPath: path,
      user: widget.user,
    );
    await context.read<ProfileViewModel>().refresh();

    if (mounted) setState(() => _pageIndex = 3);
  }

  // ============================================================
  // DRAWER ITEM CLICK (FIX-1 APPLIED)
  // ============================================================
  void _onDrawerItemClick(int index) {
    widget.sliderDrawerKey.currentState?.closeSlider();

    final isRestricted = context.read<ProfileViewModel>().isRestricted;

    if (isRestricted && index != 3) {
      _restrictedMessage();
      return;
    }

    if (_pageIndex == index) return;

    setState(() => _pageIndex = index);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final isRestricted = profileVM.isRestricted;

    return Scaffold(
      backgroundColor: AppColors.app_bg,
      body: SafeArea(
        child: SliderDrawer(
          key: widget.sliderDrawerKey,
          isDraggable: false,
          sliderOpenSize: 240,
          appBar: SliderAppBar(
            config: SliderAppBarConfig(
              backgroundColor: _appBarColor,
              title: Text(
                _titles[_pageIndex],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          slider: DrawerMenu(
            currentPageIndex: _pageIndex,
            drawerKey: widget.sliderDrawerKey,
            onItemClick: _onDrawerItemClick, // ✅ FIX-1
            user: widget.user,
          ),
          child: _screens[_pageIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: CurvedNavigationBar(
          index: _pageIndex,
          height: 60,
          backgroundColor: Colors.transparent,
          color: AppColors.darkgreen,
          buttonBackgroundColor: AppColors.darkgreen,
          items: const [
            Icon(Icons.home, color: Colors.white),
            Icon(Icons.search, color: Colors.white),
            Icon(Icons.bar_chart, color: Colors.white),
            Icon(Icons.person, color: Colors.white),
          ],
          onTap: (i) {
            if (isRestricted && i != 3) {
              _restrictedMessage();
              return;
            }
            setState(() => _pageIndex = i);
          },
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Color get _appBarColor {
    switch (_pageIndex) {
      case 0:
        return AppColors.homeColor;
      case 1:
        return AppColors.searchColor;
      case 2:
        return AppColors.reportsColor;
      default:
        return AppColors.profileColor;
    }
  }


  void _restrictedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Feature restricted by administrator."),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
}

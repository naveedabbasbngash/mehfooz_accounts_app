// lib/ui/home/home_wrapper.dart

import 'dart:async';
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../main.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/sqlite_import_service.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/profile/profile_view_model.dart';

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

  const HomeWrapper({
    super.key,
    required this.user,
    required this.sliderDrawerKey,
    this.initialTabIndex = 0,
  });

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  StreamSubscription<List<SharedMediaFile>>? _intentStream;

  late int _pageIndex = widget.initialTabIndex;
  bool _initDone = false;

  final List<String> _titles = ["Home", "Transaction", "Reports", "Profile"];

  final List<Widget> _screens = const [
    HomeScreenContent(),
    TransactionScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenToSharedFiles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initDone) return;
    _initDone = true;

    Future.microtask(() async {
      final homeVM = context.read<HomeViewModel>();
      final profileVM = context.read<ProfileViewModel>();

      await homeVM.init(user: widget.user);
      await profileVM.refresh();

      // 🚨 Always force Profile tab if restricted
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

  // ============================================================
  // ANDROID SHARE INTENT
  // ============================================================
  void _listenToSharedFiles() {
    if (!Platform.isAndroid) return;

    _intentStream =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
          _handleImport(files);
        });

    ReceiveSharingIntent.instance.getInitialMedia().then((files) async {
      if (files.isNotEmpty) {
        await _handleImport(files);
      }
      await ReceiveSharingIntent.instance.reset();
    });
  }

  // ============================================================
  // IMPORT HANDLER
  // ============================================================
  Future<void> _handleImport(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    try {
      final file = files.first;
      final path = file.path.toLowerCase();

      if (!path.endsWith(".sqlite") && !path.endsWith(".db")) {
        _showError("Only .sqlite or .db files allowed");
        return;
      }

      final savedPath =
      await SqliteImportService.importAndSaveDb(file.path);

      if (savedPath == null) {
        _showError("Import failed");
        return;
      }

      await context
          .read<HomeViewModel>()
          .importDatabase(savedPath, widget.user);

      await context.read<ProfileViewModel>().refresh();

      if (mounted) setState(() => _pageIndex = 3);
    } catch (e) {
      _showError(e.toString());
    }
  }

  // ============================================================
  // iOS IMPORT
  // ============================================================
  Future<void> _importForIOS() async {
    final path = await FilePickerService.pickSqliteFile();
    if (path == null) return;

    await context.read<HomeViewModel>().importDatabase(path, widget.user);
    await context.read<ProfileViewModel>().refresh();

    if (mounted) setState(() => _pageIndex = 3);
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
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "import_ios") _importForIOS();
                  if (value == "debug") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsWrapper()),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "import_ios",
                    child: Text("Import DB"),
                  ),
                  PopupMenuItem(
                    value: "debug",
                    child: Text("Debug Database"),
                  ),
                ],
              ),
            ),
          ),
          slider: DrawerMenu(
            currentPageIndex: _pageIndex,
            drawerKey: widget.sliderDrawerKey,
            onItemClick: _onDrawerItemClick,
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

  void _onDrawerItemClick(String title) {
    widget.sliderDrawerKey.currentState?.closeSlider();

    final isRestricted = context.read<ProfileViewModel>().isRestricted;

    if (isRestricted && title != "Profile") {
      _restrictedMessage();
      return;
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      switch (title) {
        case "Home":
          setState(() => _pageIndex = 0);
          break;
        case "Search":
          setState(() => _pageIndex = 1);
          break;
        case "Reports":
          setState(() => _pageIndex = 2);
          break;
        case "Profile":
          setState(() => _pageIndex = 3);
          break;
        case "Settings":
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsWrapper()),
          );
          break;
        case "Logout":
          _logout();
          break;
      }
    });
  }

  Future<void> _logout() async {
    // 1) signout + clear local saved user
    await AuthService.logout();

    // 2) HARD reset (DB + GlobalState + prefs)
    final appState = context.findAncestorStateOfType<MahfoozAppState>();
    await appState?.hardResetSession();

    // 3) rebuild app state properly
    appState?.resetUser();

    if (!mounted) return;

    // 4) go to login cleanly (no new MahfoozApp widget push)
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
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
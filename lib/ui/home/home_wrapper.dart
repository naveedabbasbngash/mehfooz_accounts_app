// lib/ui/home/home_wrapper.dart

import 'dart:async';
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/sqlite_import_service.dart';
import '../../theme/app_colors.dart';
import '../../viewmodel/home/home_view_model.dart';
import '../../viewmodel/profile/profile_view_model.dart';
import '../drawer/drawer_menu.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';
import 'import_summary_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports.dart';
import '../search/search_screen.dart';
import '../settings/settings_wrapper.dart';

class HomeWrapper extends StatefulWidget {
  final UserModel user;
  final GlobalKey<SliderDrawerState> sliderDrawerKey;

  const HomeWrapper({
    super.key,
    required this.user,
    required this.sliderDrawerKey,
  });

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  StreamSubscription<List<SharedMediaFile>>? _intentStream;
  int _pageIndex = 0;

  late final List<Widget> _screens = [
    const HomeScreenContent(),
    const SearchScreen(),
    const ReportsScreen(),
    ChangeNotifierProvider(
      create: (_) => ProfileViewModel(loggedInUser: widget.user),
      child: const ProfileScreen(),
    )  ];

  final List<String> _titles = [
    "Home",
    "Search",
    "Reports",
    "Profile"
  ];

  // ================================================================
  // INIT
  // ================================================================
  @override
  void initState() {
    super.initState();

    // Restore DB only if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().init(
        isUserLoggedIn:
        widget.user.isLogin == 1 && widget.user.email.isNotEmpty,
      );
    });

    _listenToSharedFiles();
  }

  @override
  void dispose() {
    _intentStream?.cancel();
    _intentStream = null;
    super.dispose();
  }

  // ================================================================
  // ANDROID SHARE INTENT
  // ================================================================
  void _listenToSharedFiles() {
    if (!Platform.isAndroid) return;

    _intentStream = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((files) => _processShare(files));

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((files) => _processShare(files));
  }

  Future<void> _processShare(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final f = files.first;

    if (!f.path.toLowerCase().endsWith(".sqlite") &&
        !f.path.toLowerCase().endsWith(".db")) {
      _showError("❌ Only .sqlite or .db allowed.");
      return;
    }

    final savedPath = await SqliteImportService.importAndSaveDb(f.path);
    if (savedPath == null) {
      _showError("❌ Failed to import file.");
      return;
    }

    final vm = context.read<HomeViewModel>();
    await vm.importDatabase(savedPath);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportSummaryScreen(
          filePath: savedPath,
          user: widget.user,
        ),
      ),
    );
  }

  // ================================================================
  // IOS FILE PICKER
  // ================================================================
  Future<void> importForIOS() async {
    final path = await FilePickerService.pickSqliteFile();
    if (path == null) {
      _showError("No file selected");
      return;
    }

    final vm = context.read<HomeViewModel>();
    await vm.importDatabase(path);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportSummaryScreen(
          filePath: path,
          user: widget.user,
        ),
      ),
    );
  }

  // ================================================================
  // POPUP MENU ACTIONS
  // ================================================================
  void onMenuSelected(String value) {
    switch (value) {
      case "import_android":
        _showError("Android: Share a .sqlite file via WhatsApp");
        break;

      case "import_ios":
        importForIOS();
        break;

      case "debug":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsWrapper()),
        );
        break;
    }
  }

  // ================================================================
  // ERROR DIALOG
  // ================================================================
  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // APP BAR COLOR
  // ================================================================
  Color get _getAppBarColor {
    switch (_pageIndex) {
      case 0:
        return AppColors.homeColor;
      case 1:
        return AppColors.searchColor;
      case 2:
        return AppColors.reportsColor;
      case 3:
        return AppColors.profileColor;
      default:
        return AppColors.primary;
    }
  }

  // ================================================================
  // UI
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app_bg,
      body: SafeArea(
        child: SliderDrawer(
          key: widget.sliderDrawerKey,
          isDraggable: false,
          appBar: SliderAppBar(
            config: SliderAppBarConfig(
              backgroundColor: _getAppBarColor,
              title: Text(
                _titles[_pageIndex],
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: onMenuSelected,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "import_android",
                    child: Text("Import DB (Android Share)"),
                  ),
                  PopupMenuItem(
                    value: "import_ios",
                    child: Text("Import DB (iOS)"),
                  ),
                  PopupMenuItem(
                    value: "debug",
                    child: Text("Debug Database"),
                  ),
                ],
              ),
            ),
          ),
          sliderOpenSize: 240,
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
          backgroundColor: Colors.transparent,
          color: AppColors.navBarBackground,
          buttonBackgroundColor: AppColors.navBarBackground,
          height: 60,
          index: _pageIndex,
          items: const [
            Icon(Icons.home, size: 30),
            Icon(Icons.search, size: 30),
            Icon(Icons.bar_chart, size: 30),
            Icon(Icons.person, size: 30),
          ],
          onTap: (i) => setState(() => _pageIndex = i),
        ),
      ),
    );
  }

  // ================================================================
  // DRAWER ACTIONS
  // ================================================================
  void _onDrawerItemClick(String title) async {
    widget.sliderDrawerKey.currentState?.closeSlider();

    Future.delayed(const Duration(milliseconds: 250), () async {
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
          await AuthService.logout();

          // RESET USER IN main.dart STATE
          context.findAncestorStateOfType<MahfoozAppState>()?.resetUser();

          // CLEAR SHARE INTENT STREAM
          await _intentStream?.cancel();
          _intentStream = null;

          if (!mounted) return;

          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          break;
      }
    });
  }
}
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// SQLite bindings for iOS/Android
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'model/user_model.dart';
import 'services/auth_service.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/home/home_wrapper.dart';
import 'viewmodel/home/home_view_model.dart';

// 🔥 SYNC
import 'services/sync/sync_service.dart';
import 'viewmodel/sync/sync_viewmodel.dart';

import 'data/local/database_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ur', 'PK'),
        Locale('ar', 'SA'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en', 'US'),
      child: const MahfoozApp(),
    ),
  );
}

class MahfoozApp extends StatefulWidget {
  const MahfoozApp({super.key});

  @override
  MahfoozAppState createState() => MahfoozAppState();
}

class MahfoozAppState extends State<MahfoozApp> {
  UserModel? _user;
  bool _loading = true;

  // Global Keys
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<SliderDrawerState> _sliderDrawerKey =
  GlobalKey<SliderDrawerState>();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _user = await AuthService.loadSavedUser();
    setState(() => _loading = false);
  }

  /// Called by logout
  void resetUser() {
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final bool isLoggedIn = _user != null && _user!.isLogin == 1;

    // 🔥 Create syncService only (NO syncRepo here)
    final syncService =
    SyncService(baseUrl: "https://kheloaurjeeto.net/mahfooz_accounts/");

    return MultiProvider(
      providers: [
        /// --------------------------------------------------------------
        /// HOME VIEWMODEL
        /// --------------------------------------------------------------
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            navigatorKey: _navigatorKey,
            drawerKey: _sliderDrawerKey,
          ),
        ),

        /// --------------------------------------------------------------
        /// SYNC VIEWMODEL
        /// --------------------------------------------------------------
        ChangeNotifierProvider<SyncViewModel>(
          create: (_) => SyncViewModel(
            syncService: syncService,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          // 🔥 CONNECT HomeViewModel → SyncViewModel
          final homeVM = context.read<HomeViewModel>();
          final syncVM = context.read<SyncViewModel>();
          homeVM.registerSyncVM(syncVM);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,

            // Localization support
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,

            // --------------------------------------------------------------
            // App startup screen (login or home)
            // --------------------------------------------------------------
            home: isLoggedIn
                ? HomeWrapper(
              user: _user!,
              sliderDrawerKey: _sliderDrawerKey,
            )
                : AuthScreen(
              sliderDrawerKey: _sliderDrawerKey,
            ),
          );
        },
      ),
    );
  }
}
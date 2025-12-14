// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:mehfooz_accounts_app/services/global_state.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/user_model.dart';
import 'services/auth_service.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/home/home_wrapper.dart';

import 'viewmodel/home/home_view_model.dart';
import 'viewmodel/profile/profile_view_model.dart';
import 'viewmodel/sync/sync_viewmodel.dart';
import 'services/sync/sync_service.dart';

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
  bool _userDbExists = false;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();
  final GlobalKey<SliderDrawerState> _drawerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _user = await AuthService.loadSavedUser();

    if (_user != null && _user!.isLogin == 1) {
      _userDbExists = await DatabaseManager.instance
          .restoreDatabaseForUser(_user!.email);
    }

    setState(() => _loading = false);
  }

  /// 🔁 Called by logout (from HomeWrapper)
  void resetUser() async {
    _userDbExists = false;
    _loading = true;
    setState(() {});

    // Reload user & DB info fresh from disk
    await _loadUser();

    _loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final isLoggedIn = _user != null && _user!.isLogin == 1;

    return MultiProvider(
      key: ValueKey(_user?.email ?? "no_user"),
      providers: [
        // 🔹 Home VM
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            navigatorKey: _navigatorKey,
            drawerKey: _drawerKey,
          ),
        ),

        // 🔹 Sync VM (only creates service, DB is attached later)
        ChangeNotifierProvider(
          create: (_) => SyncViewModel(
            syncService: SyncService(
              baseUrl: "https://kheloaurjeeto.net/mahfooz_accounts/",
            ),
          ),
        ),

        // 🔹 Profile VM (only when logged in)
        if (isLoggedIn)
          ChangeNotifierProvider(
            create: (_) => ProfileViewModel(
              loggedInUser: _user!, // real logged-in user
            ),
          ),
      ],
      child: Builder(
        builder: (context) {
          // ⭐ IMPORTANT: connect HomeViewModel ↔ SyncViewModel here
          final homeVM = context.read<HomeViewModel>();
          final syncVM = context.read<SyncViewModel>();
          homeVM.registerSyncVM(syncVM);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,

            // EasyLocalization hookup
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,

            home: isLoggedIn
                ? HomeWrapper(
              user: _user!,
              sliderDrawerKey: _drawerKey,
              initialTabIndex: _userDbExists ? 0 : 3,
            )
                : AuthScreen(sliderDrawerKey: _drawerKey),
          );
        },
      ),
    );
  }

  Future<void> hardResetSession() async {
    // 1) Reset DB (prevents drift reusing old user DB)
    await DatabaseManager.instance.reset();

    // 2) Reset GlobalState (you must add reset() in GlobalState, see below)
    try {
      GlobalState.instance.reset();
    } catch (_) {}

    // 3) Clear non-user-scoped prefs
    //    (These keys caused leakage across accounts)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("selected_company_id");
      await prefs.remove("profile_is_restricted");
    } catch (_) {}

    // 4) Reset in-memory app state
    _user = null;
    _userDbExists = false;
  }
}
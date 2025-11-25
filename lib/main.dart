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

/// ===============================================================
/// PUBLIC STATE CLASS (Fix for logout reload)
/// ===============================================================
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

  /// ==============================================================
  /// LOAD USER FROM LOCAL STORAGE (decides opening screen)
  /// ==============================================================
  Future<void> _loadUser() async {
    _user = await AuthService.loadSavedUser();
    setState(() => _loading = false);
  }

  /// ==============================================================
  /// CALLED BY LOGOUT TO RESET THE USER + RELOAD UI
  /// ==============================================================
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            navigatorKey: _navigatorKey,
            drawerKey: _sliderDrawerKey,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,

        // Localization support
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,

        /// =========================================================
        /// FIXED ROUTER: uses latest user from storage
        /// =========================================================
        home: isLoggedIn
            ? HomeWrapper(
          user: _user!,
          sliderDrawerKey: _sliderDrawerKey,
        )
            : AuthScreen(
          sliderDrawerKey: _sliderDrawerKey,
        ),
      ),
    );
  }
}
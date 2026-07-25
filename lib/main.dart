// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:mehfooz_accounts_app/services/sync/pending_share.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'model/user_model.dart';
import 'services/auth_service.dart';
import 'services/global_state.dart';

import 'ui/auth/auth_screen.dart';
import 'ui/home/home_wrapper.dart';

import 'viewmodel/home/home_view_model.dart';
import 'viewmodel/profile/profile_view_model.dart';
import 'viewmodel/sync/sync_viewmodel.dart';

import 'services/sync/sync_service.dart';
import 'services/sync/sync_invalidation_store.dart';
import 'data/local/database_manager.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
  await SyncInvalidationStore.markFromPayload(
    message.data,
    source: 'fcm-background',
  );
}

Future<void> _ensureFirebaseInitialized() async {
  try {
    Firebase.app();
    return;
  } catch (_) {
    // App not yet visible to Dart side; continue.
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // Native side may have initialized [DEFAULT] just before this call.
    if (e.code == 'duplicate-app') {
      return;
    }
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 REQUIRED
  await _ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
  State<MahfoozApp> createState() => MahfoozAppState();
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

  // ─────────────────────────────────────────────
  // LOAD USER + DB STATE
  // ─────────────────────────────────────────────
  Future<void> _loadUser() async {
    _user = await AuthService.loadSavedUser();

    if (_user != null && _user!.isLogin == 1) {
      _userDbExists = await DatabaseManager.instance.restoreDatabaseForUser(
        _user!.email,
      );
    }

    setState(() => _loading = false);
  }

  // ─────────────────────────────────────────────
  // LOGOUT RESET
  // ─────────────────────────────────────────────
  void resetUser() async {
    _userDbExists = false;
    _loading = true;
    setState(() {});

    await _loadUser();

    _loading = false;
    setState(() {});
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final bool isLoggedIn = _user != null && _user!.isLogin == 1;

    return MultiProvider(
      key: ValueKey(_user?.email ?? "no_user"),
      providers: [
        // ─── Home VM
        ChangeNotifierProvider(
          create: (_) =>
              HomeViewModel(navigatorKey: _navigatorKey, drawerKey: _drawerKey),
        ),

        // ─── Sync VM
        ChangeNotifierProvider(
          create: (_) => SyncViewModel(
            syncService: SyncService(
              baseUrl: "https://mkb.mahfoozaccounts.com/",
            ),
          ),
        ),

        // ─── Profile VM (only when logged in)
        if (isLoggedIn)
          ChangeNotifierProvider(
            create: (_) => ProfileViewModel(loggedInUser: _user!),
          ),
      ],
      child: Builder(
        builder: (context) {
          final homeVM = context.read<HomeViewModel>();
          final syncVM = context.read<SyncViewModel>();

          // 🔗 CONNECT HOME ↔ SYNC
          if (_user != null) {
            homeVM.registerSyncVM(syncVM, _user!);
          }

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,

            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,

            onGenerateRoute: (settings) {
              final name = settings.name;

              // 🔥 iOS Open-In handler
              if (name != null &&
                  name.startsWith("file://") &&
                  PendingShare.path == null) {
                PendingShare.path = name.replaceFirst("file://", "");
                debugPrint(
                  "📥 iOS Open-In route captured: ${PendingShare.path}",
                );
              }

              return MaterialPageRoute(
                builder: (_) => isLoggedIn
                    ? HomeWrapper(
                        user: _user!,
                        sliderDrawerKey: _drawerKey,
                        initialTabIndex: _userDbExists ? 0 : 3,
                      )
                    : AuthScreen(),
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HARD RESET (SAFETY)
  // ─────────────────────────────────────────────
  Future<void> hardResetSession() async {
    await DatabaseManager.instance.reset();

    try {
      GlobalState.instance.reset();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("selected_company_id");
      await prefs.remove("selected_company_guid");
      await prefs.remove("profile_is_restricted");
    } catch (_) {}

    _user = null;
    _userDbExists = false;
  }

  // ─────────────────────────────────────────────
  // CALLED AFTER SUCCESSFUL LOGIN
  // ─────────────────────────────────────────────
  Future<void> onLoginSuccess() async {
    setState(() => _loading = true);

    _user = await AuthService.loadSavedUser();

    if (_user != null && _user!.isLogin == 1) {
      _userDbExists = await DatabaseManager.instance.restoreDatabaseForUser(
        _user!.email,
      );
    } else {
      _userDbExists = false;
    }

    setState(() => _loading = false);
  }
}

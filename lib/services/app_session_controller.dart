import 'package:flutter/foundation.dart';
import '../data/local/database_manager.dart';
import '../services/global_state.dart';
import '../services/auth_service.dart';
import '../model/user_model.dart';

class AppSessionController extends ChangeNotifier {
  UserModel? _user;
  bool _loading = true;
  bool _userDbExists = false;

  UserModel? get user => _user;
  bool get isLoading => _loading;
  bool get userDbExists => _userDbExists;

  // ─────────────────────────────────────────────
  Future<void> loadUser() async {
    _loading = true;
    notifyListeners();

    _user = await AuthService.loadSavedUser();

    if (_user != null && _user!.isLogin == 1) {
      _userDbExists =
      await DatabaseManager.instance.restoreDatabaseForUser(_user!.email);
    } else {
      _userDbExists = false;
    }

    _loading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  Future<void> resetSession() async {
    // 1️⃣ Reset DB
    await DatabaseManager.instance.reset();

    // 2️⃣ Reset GlobalState
    try {
      GlobalState.instance.reset();
    } catch (_) {}

    // 3️⃣ Reload user from disk
    await loadUser();
  }

  // ─────────────────────────────────────────────
  Future<void> logout() async {
    await AuthService.logout();
    await resetSession();
  }
}
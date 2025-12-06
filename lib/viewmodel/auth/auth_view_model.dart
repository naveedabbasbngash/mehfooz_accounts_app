// lib/viewmodel/auth/auth_view_model.dart
import 'package:flutter/foundation.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';

import 'package:flutter/foundation.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  // Dependency injected function (default = real Google login)
  final Future<UserModel?> Function() loginFn;

  AuthViewModel({
    Future<UserModel?> Function()? loginFn,
  }) : loginFn = loginFn ?? AuthService.loginWithGoogle;

  bool isLoading = false;
  String? errorMessage;
  UserModel? user;

  // ===========================
  // MAIN LOGIN
  // (used by UI)
  // ===========================
  Future<UserModel?> loginWithGoogle() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final UserModel? result = await loginFn();

      isLoading = false;

      if (result == null) {
        errorMessage = "Login failed. Please try again.";
        notifyListeners();
        return null;
      }

      if (!result.status) {
        errorMessage = result.message;
        user = result;
        notifyListeners();
        return result;
      }

      user = result;
      notifyListeners();
      return result;
    } catch (e) {
      isLoading = false;
      errorMessage = "Unexpected error";
      notifyListeners();
      return null;
    }
  }

  // OPTIONAL alias (for your older tests)
  Future<UserModel?> login() => loginWithGoogle();
}
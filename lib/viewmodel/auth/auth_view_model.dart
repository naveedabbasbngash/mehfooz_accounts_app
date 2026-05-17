// lib/viewmodel/auth/auth_view_model.dart
// COMPLETE • TASKS 1–5 • BUILD SAFE

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/local_storage.dart';
import '../../services/logging/logger_service.dart';

enum AuthStep {
  chooser,
  email,
  register,
  password,
  setPassword,
  forgotPassword,
  contact,
}

class AuthRegisterUiResult {
  final bool success;
  final String message;

  const AuthRegisterUiResult({required this.success, required this.message});
}

class AuthViewModel extends ChangeNotifier {
  // ─────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────
  bool isLoading = false;

  String? errorMessage;
  String? infoMessage;

  bool forgotPasswordSuccess = false;

  /// TASK 1: remember account
  bool rememberPassword = true;

  String email = '';
  AuthStep step = AuthStep.email;

  UserModel? user;

  // ACCOUNT CHOOSER
  List<UserModel> savedAccounts = [];
  UserModel? lastUsedAccount;

  // ─────────────────────────────────────────────
  // INIT (TASK 5)
  // ─────────────────────────────────────────────
  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    try {
      savedAccounts = await AuthService.loadAllSavedUsers();
      lastUsedAccount = await AuthService.loadLastUsedUser();

      step = savedAccounts.isNotEmpty ? AuthStep.chooser : AuthStep.email;
    } catch (e) {
      LoggerService.warn('Auth init failed: $e');
      step = AuthStep.email;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // QUICK LOGIN (CHOOSER)
  // ─────────────────────────────────────────────
  Future<UserModel?> quickLogin(UserModel account) async {
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;

    isLoading = true;
    notifyListeners();

    try {
      final loggedIn = await AuthService.quickLogin(account);
      user = loggedIn;
      return loggedIn;
    } catch (_) {
      await removeAccount(account.email);
      errorMessage = 'Account not available. Please login again.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // REMOVE ACCOUNT (TASK 4)
  // ─────────────────────────────────────────────
  Future<void> removeAccount(String email) async {
    await LocalStorageService.removeUser(email);
    savedAccounts.removeWhere((u) => u.email == email);

    if (lastUsedAccount?.email == email) {
      lastUsedAccount = null;
      await LocalStorageService.clearLastUsedUser();
    }

    this.email = '';
    step = savedAccounts.isNotEmpty ? AuthStep.chooser : AuthStep.email;

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // USE ANOTHER ACCOUNT
  // ─────────────────────────────────────────────
  void useAnotherAccount() {
    email = '';
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.email;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // SELECT ACCOUNT FROM CHOOSER
  // ─────────────────────────────────────────────
  void selectSavedAccount(String selectedEmail) {
    email = selectedEmail.trim();
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.password;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // OPEN REGISTER
  // ─────────────────────────────────────────────
  void openRegister({String? prefillEmail}) {
    email = (prefillEmail ?? email).trim();
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.register;
    notifyListeners();
  }

  void openEmailStep({String? prefillEmail}) {
    email = (prefillEmail ?? email).trim();
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.email;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // SUBMIT EMAIL
  // ─────────────────────────────────────────────
  Future<void> submitEmail(String value) async {
    email = value.trim();
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;

    if (email.isEmpty) {
      errorMessage = 'Please enter your email';
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.checkEmail(email);

      if (result.step == 'contact' ||
          result.message.toLowerCase().contains('not found')) {
        step = AuthStep.contact;
      } else if (result.hasPassword) {
        step = AuthStep.password;
      } else {
        step = AuthStep.setPassword;
      }
    } catch (_) {
      errorMessage = 'Unable to verify email';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // LOGIN WITH PASSWORD
  // ─────────────────────────────────────────────
  Future<UserModel?> loginWithPassword(String password) async {
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;

    if (password.trim().isEmpty) {
      errorMessage = 'Password is required';
      notifyListeners();
      return null;
    }

    isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.loginWithPassword(
        email: email,
        password: password.trim(),
      );

      if (result == null) {
        errorMessage = 'Invalid email or password';
        return null;
      }

      user = result;
      return result;
    } on AuthStepException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (_) {
      errorMessage = 'Login failed';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────
  Future<AuthRegisterUiResult> registerAccount({
    required String firstName,
    required String lastName,
    required String emailValue,
    required String password,
    required String confirmPassword,
  }) async {
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;

    final fName = firstName.trim();
    final lName = lastName.trim();
    final mail = emailValue.trim();
    final p1 = password.trim();
    final p2 = confirmPassword.trim();

    if (fName.isEmpty) {
      const msg = 'First name is required';
      errorMessage = msg;
      notifyListeners();
      return const AuthRegisterUiResult(success: false, message: msg);
    }
    if (mail.isEmpty) {
      const msg = 'Email is required';
      errorMessage = msg;
      notifyListeners();
      return const AuthRegisterUiResult(success: false, message: msg);
    }
    if (p1.isEmpty || p2.isEmpty) {
      const msg = 'Password fields cannot be empty';
      errorMessage = msg;
      notifyListeners();
      return const AuthRegisterUiResult(success: false, message: msg);
    }
    if (p1.length < 6) {
      const msg = 'Password must be at least 6 characters';
      errorMessage = msg;
      notifyListeners();
      return const AuthRegisterUiResult(success: false, message: msg);
    }
    if (p1 != p2) {
      const msg = 'Passwords do not match';
      errorMessage = msg;
      notifyListeners();
      return const AuthRegisterUiResult(success: false, message: msg);
    }

    isLoading = true;
    notifyListeners();

    try {
      final registerResult = await AuthService.registerAccount(
        firstName: fName,
        lastName: lName,
        email: mail,
        password: p1,
        confirmPassword: p2,
      );

      if (!registerResult.success) {
        final msg = registerResult.message.isNotEmpty
            ? registerResult.message
            : 'Registration failed';
        errorMessage = msg;
        return AuthRegisterUiResult(success: false, message: msg);
      }

      email = mail;
      final successMsg = registerResult.message.isNotEmpty
          ? registerResult.message
          : 'Account created successfully';
      infoMessage = successMsg;
      return AuthRegisterUiResult(success: true, message: successMsg);
    } on AuthStepException catch (e) {
      errorMessage = e.message;
      return AuthRegisterUiResult(success: false, message: e.message);
    } catch (_) {
      const msg = 'Registration failed';
      errorMessage = msg;
      return const AuthRegisterUiResult(success: false, message: msg);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // SET PASSWORD
  // ─────────────────────────────────────────────
  Future<bool> setPassword(String password, String confirmPassword) async {
    errorMessage = null;

    final p1 = password.trim();
    final p2 = confirmPassword.trim();

    if (p1.isEmpty || p2.isEmpty) {
      errorMessage = 'Password fields cannot be empty';
      notifyListeners();
      return false;
    }

    if (p1 != p2) {
      errorMessage = 'Passwords do not match';
      notifyListeners();
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      final ok = await AuthService.setPassword(
        email: email,
        password: p1,
        confirmPassword: p2,
      );

      if (!ok) {
        errorMessage = 'Unable to set password';
        return false;
      }

      step = AuthStep.password;
      return true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // ✅ FIX: FORGOT PASSWORD NAVIGATION
  // ─────────────────────────────────────────────
  void goToForgotPassword() {
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.forgotPassword;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // FORGOT PASSWORD API
  // ─────────────────────────────────────────────
  Future<bool> forgotPassword(String value) async {
    email = value.trim();
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;

    if (email.isEmpty) {
      errorMessage = 'Please enter your email';
      notifyListeners();
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('https://admin.mahfoozaccounts.com/api/forgotPassword'),
        body: {'email': email},
      );

      final decoded = jsonDecode(response.body);
      final ok = decoded['status'] == true;

      if (ok) {
        infoMessage = decoded['message'] ?? 'Reset link sent';
        forgotPasswordSuccess = true;
        return true;
      } else {
        errorMessage = decoded['message'] ?? 'Unable to send reset link';
        return false;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // BACK NAVIGATION (TASK 2 & 3)
  // ─────────────────────────────────────────────
  void goBack() {
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    email = '';

    step = savedAccounts.isNotEmpty ? AuthStep.chooser : AuthStep.email;

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────
  void reset() {
    email = '';
    user = null;
    errorMessage = null;
    infoMessage = null;
    forgotPasswordSuccess = false;
    step = AuthStep.email;
    notifyListeners();
  }
}

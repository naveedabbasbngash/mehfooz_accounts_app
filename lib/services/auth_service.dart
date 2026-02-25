// ==============================
// lib/services/auth_service.dart
// FINAL • STABLE • CHOOSER-SAFE
// ❌ NEVER deletes accounts automatically
// ✅ ViewModel decides navigation & removal
// ==============================

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/user_model.dart';
import 'local_storage.dart';
import 'logging/logger_service.dart';

// ─────────────────────────────────────────────
// SUPPORT TYPES
// ─────────────────────────────────────────────
enum AuthStepType { setPassword, error, backToEmail }

class AuthStepException implements Exception {
  final AuthStepType step;
  final String message;

  AuthStepException({required this.step, required this.message});

  @override
  String toString() => 'AuthStepException(step=$step, message=$message)';
}

class AuthService {
  static const String _base = 'https://admin.mahfoozaccounts.com/api';

  // ============================================================
  // STEP 1: CHECK EMAIL
  // ============================================================
  static Future<AuthCheckResult> checkEmail(String email) async {
    final checkEmailUri = Uri.parse('$_base/loginWithPassword');
    final checkEmailParams = <String, String>{'email': email};

    LoggerService.info('📧 [CHECK_EMAIL] URL=$checkEmailUri');
    LoggerService.info('📧 [CHECK_EMAIL] PARAMS=$checkEmailParams');

    final res = await http.post(checkEmailUri, body: {'email': email});

    LoggerService.info('📡 [CHECK_EMAIL] ${res.statusCode} | ${res.body}');

    final json = jsonDecode(res.body);
    return AuthCheckResult.fromJson(json);
  }

  // ============================================================
  // STEP 2: LOGIN WITH PASSWORD
  // ============================================================
  static Future<UserModel?> loginWithPassword({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final loginUri = Uri.parse('$_base/loginWithPassword');
    final loginParams = <String, String>{
      'email': email,
      // Keep password masked in logs for safety while still showing payload shape.
      'password': '*' * password.length,
    };

    LoggerService.info('🔐 [LOGIN] URL=$loginUri');
    LoggerService.info('🔐 [LOGIN] PARAMS=$loginParams | remember=$rememberMe');

    final res = await http.post(
      loginUri,
      body: {'email': email, 'password': password},
    );

    LoggerService.info('📡 [LOGIN] ${res.statusCode} | ${res.body}');

    final Map<String, dynamic> json = jsonDecode(res.body);

    // ❌ Backend rejection
    if (json['status'] != true || json['data'] == null) {
      final String step = (json['step'] ?? '').toString();
      final String message = (json['message'] ?? 'Login failed').toString();

      LoggerService.warn('❌ [LOGIN] Rejected | step=$step | msg=$message');

      if (step == 'password') {
        throw AuthStepException(
          step: AuthStepType.setPassword,
          message: message,
        );
      }

      // ❗ IMPORTANT:
      // ❌ DO NOT remove local accounts here
      throw AuthStepException(step: AuthStepType.backToEmail, message: message);
    }

    final user = UserModel.fromApiResponse(json);

    if (user.email.isEmpty) {
      throw AuthStepException(
        step: AuthStepType.backToEmail,
        message: 'Invalid account state',
      );
    }

    // ✅ Save ONLY on success
    if (rememberMe) {
      await LocalStorageService.saveOrUpdateUser(user);
    }

    await LocalStorageService.setLastUsedUser(user.email);

    LoggerService.info('✅ [LOGIN] Success | ${user.email}');
    return user;
  }

  // ============================================================
  // STEP 3: SET PASSWORD
  // ============================================================
  static Future<bool> setPassword({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    LoggerService.info('🔑 [SET_PASSWORD] email=$email');

    final res = await http.post(
      Uri.parse('$_base/setPassword'),
      body: {
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );

    LoggerService.info('📡 [SET_PASSWORD] ${res.statusCode} | ${res.body}');

    final json = jsonDecode(res.body);
    return json['status'] == true;
  }

  // ============================================================
  // ACCOUNT CHOOSER
  // ============================================================
  static Future<List<UserModel>> loadAllSavedUsers() async {
    return await LocalStorageService.loadAllUsers();
  }

  static Future<UserModel?> loadLastUsedUser() async {
    return await LocalStorageService.loadLastUsedUser();
  }

  static Future<UserModel?> loadSavedUser() async {
    return await loadLastUsedUser();
  }

  // ============================================================
  // QUICK LOGIN (CHOOSER TAP)
  // ============================================================
  static Future<UserModel?> quickLogin(UserModel account) async {
    LoggerService.info('⚡ [QUICK_LOGIN] email=${account.email}');

    final res = await http.post(
      Uri.parse('$_base/loginWithPassword'),
      body: {'email': account.email},
    );

    LoggerService.info('📡 [QUICK_LOGIN] ${res.statusCode} | ${res.body}');

    final Map<String, dynamic> json = jsonDecode(res.body);

    // ❗ If password required or backend refuses
    if (json['status'] != true ||
        json['step'] == 'password' ||
        json['data'] == null) {
      throw AuthStepException(
        step: AuthStepType.setPassword,
        message: (json['message'] ?? 'Please enter password').toString(),
      );
    }

    final freshUser = UserModel.fromApiResponse(json);

    if (freshUser.email.isEmpty) {
      throw AuthStepException(
        step: AuthStepType.backToEmail,
        message: 'Invalid account',
      );
    }

    await LocalStorageService.saveOrUpdateUser(freshUser);
    await LocalStorageService.setLastUsedUser(freshUser.email);

    LoggerService.info('✅ [QUICK_LOGIN] Success | ${freshUser.email}');

    return freshUser;
  }

  // ============================================================
  // REMOVE ACCOUNT (MANUAL ONLY)
  // ============================================================
  static Future<void> removeAccount(String email) async {
    LoggerService.info('🗑️ [REMOVE_ACCOUNT] email=$email');
    await LocalStorageService.removeUser(email);
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  static Future<void> logout() async {
    LoggerService.info('🚪 [LOGOUT]');
    await LocalStorageService.clearLoginStateOnly();
  }
}

// ==============================
// AUTH CHECK RESULT
// ==============================
class AuthCheckResult {
  final String step;
  final String message;

  AuthCheckResult({required this.step, required this.message});

  bool get emailExists => step != 'contact';

  bool get hasPassword =>
      step == 'password' && !message.toLowerCase().contains('not set');

  factory AuthCheckResult.fromJson(Map<String, dynamic> json) {
    return AuthCheckResult(
      step: (json['step'] ?? 'contact').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}

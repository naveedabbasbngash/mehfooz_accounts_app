// ==============================
// lib/services/auth_service.dart
// FINAL • STABLE • CHOOSER-SAFE
// ❌ NEVER deletes accounts automatically
// ✅ ViewModel decides navigation & removal
// ==============================

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/subscription_package_option.dart';
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
  static const List<String> _loginEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/auth/login',
    'https://mkb.mahfoozaccounts.com/api/v1/auth/login',
  ];
  static const List<String> _registerEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/auth/register',
  ];
  static const List<String> _usersCreateEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/users',
    'https://mkb.mahfoozaccounts.com/api/v1/users',
  ];
  static const List<String> _adminRolesEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/admin/roles',
    'https://mkb.mahfoozaccounts.com/api/v1/admin/roles',
  ];
  static const List<String> _meEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/auth/me',
    'https://mkb.mahfoozaccounts.com/api/v1/auth/me',
  ];
  static const List<String> _activeSubscriptionPackageEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/subscription-packages/active',
    'https://mkb.mahfoozaccounts.com/api/v1/subscription-packages/active',
  ];

  // ============================================================
  // STEP 1: CHECK EMAIL
  // ============================================================
  static Future<AuthCheckResult> checkEmail(String email) async {
    final normalized = email.trim();
    LoggerService.info(
      '📧 [CHECK_EMAIL] MKB flow active for $normalized -> password step',
    );

    if (normalized.isEmpty) {
      return AuthCheckResult(step: 'contact', message: 'Email is required');
    }

    // MKB auth works on direct login endpoint, so we move to password step.
    return AuthCheckResult(step: 'password', message: 'Continue with password');
  }

  // ============================================================
  // STEP 2: LOGIN WITH PASSWORD
  // ============================================================
  static Future<UserModel?> loginWithPassword({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final loginParams = <String, String>{
      'email': email,
      // Keep password masked in logs for safety while still showing payload shape.
      'password': '*' * password.length,
    };
    LoggerService.info('🔐 [LOGIN] PARAMS=$loginParams | remember=$rememberMe');

    AuthStepException? lastFailure;
    for (final endpoint in _loginEndpoints) {
      final loginUri = Uri.parse(endpoint);
      LoggerService.info('🔐 [LOGIN] URL=$loginUri');

      http.Response res;
      try {
        res = await http.post(
          loginUri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_info': 'flutter-app',
          }),
        );
      } catch (_) {
        lastFailure = AuthStepException(
          step: AuthStepType.backToEmail,
          message: 'Unable to connect to login server',
        );
        continue;
      }

      LoggerService.info('📡 [LOGIN] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) {
        continue;
      }

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          // Ignore malformed JSON and handle by HTTP code fallback.
        }
      }

      if (json == null) {
        lastFailure = AuthStepException(
          step: AuthStepType.backToEmail,
          message: 'Login failed (HTTP ${res.statusCode})',
        );
        continue;
      }

      if (json['status'] != true || json['data'] == null) {
        final message = _resolveLoginFailureMessage(json);
        LoggerService.warn('❌ [LOGIN] Rejected | msg=$message');
        lastFailure = AuthStepException(
          step: AuthStepType.backToEmail,
          message: message,
        );
        continue;
      }

      final normalized = _normalizeMkbLoginResponse(json, fallbackEmail: email);
      final user = UserModel.fromApiResponse(normalized);
      final token = _extractMkbToken(json);
      final tenantId = _extractMkbTenantId(json);

      if (user.email.isEmpty) {
        lastFailure = AuthStepException(
          step: AuthStepType.backToEmail,
          message: 'Invalid account state',
        );
        continue;
      }

      if (token != null && token.isNotEmpty) {
        await LocalStorageService.saveAuthToken(
          email: user.email,
          token: token,
        );
      }
      if (tenantId != null && tenantId > 0) {
        await LocalStorageService.saveTenantId(
          email: user.email,
          tenantId: tenantId,
        );
      }

      if (rememberMe) {
        await LocalStorageService.saveOrUpdateUser(user);
      }

      await LocalStorageService.setLastUsedUser(user.email);
      LoggerService.info('✅ [LOGIN] Success | ${user.email}');
      return user;
    }

    throw lastFailure ??
        AuthStepException(
          step: AuthStepType.backToEmail,
          message: 'Login API route not found (404)',
        );
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
      Uri.parse(
        'https://mkb.mahfoozaccounts.com/index.php/api/v1/auth/setPassword',
      ),
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
  // STEP 4: REGISTER ACCOUNT
  // ============================================================
  static Future<AuthRegisterResult> registerAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final registerParams = <String, String>{
      'first_name': firstName,
      'last_name': lastName,
      'full_name': [
        firstName,
        lastName,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' '),
      'email': email,
      // Keep password masked in logs.
      'password': '*' * password.length,
      'confirm_password': '*' * confirmPassword.length,
    };
    LoggerService.info('🆕 [REGISTER] PARAMS=$registerParams');

    final requestBody = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'full_name': [
        firstName,
        lastName,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' '),
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    };

    AuthRegisterResult? lastNon404Failure;
    for (final endpoint in _registerEndpoints) {
      final registerUri = Uri.parse(endpoint);
      LoggerService.info('🆕 [REGISTER] URL=$registerUri');

      http.Response res;
      try {
        res = await http.post(
          registerUri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        );
      } catch (_) {
        lastNon404Failure = const AuthRegisterResult(
          success: false,
          message: 'Unable to connect to registration server',
        );
        continue;
      }

      LoggerService.info('📡 [REGISTER] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) {
        continue;
      }

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          // ignore parse failures and use status code fallback below
        }
      }

      if (json != null) {
        final ok = json['status'] == true;
        final message = (json['message'] ?? '').toString();
        if (ok) {
          return AuthRegisterResult(
            success: true,
            message: message.isNotEmpty ? message : 'Registration successful',
          );
        }
        lastNon404Failure = AuthRegisterResult(
          success: false,
          message: message.isNotEmpty ? message : 'Registration failed',
        );
        continue;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const AuthRegisterResult(
          success: true,
          message: 'Registration successful',
        );
      }

      lastNon404Failure = AuthRegisterResult(
        success: false,
        message: 'Registration failed (HTTP ${res.statusCode})',
      );
    }

    return lastNon404Failure ??
        const AuthRegisterResult(
          success: false,
          message:
              'Registration API route not found (404). Please enable register endpoint on server.',
        );
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
    final refreshed = await refreshCurrentUser(account);
    final resolved = refreshed ?? account;
    await LocalStorageService.saveOrUpdateUser(resolved);
    await LocalStorageService.setLastUsedUser(resolved.email);
    LoggerService.info('✅ [QUICK_LOGIN] Local success | ${resolved.email}');
    return resolved;
  }

  static Future<UserModel?> refreshCurrentUser(UserModel account) async {
    final token = await LocalStorageService.loadAuthToken(account.email);
    if (token == null || token.trim().isEmpty) return null;

    for (final endpoint in _meEndpoints) {
      final uri = Uri.parse(endpoint);
      http.Response res;
      try {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        );
      } catch (_) {
        continue;
      }

      if (res.statusCode == 404) continue;
      if (res.statusCode < 200 || res.statusCode >= 300) continue;
      if (res.body.trim().isEmpty) continue;

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (json['status'] != true || json['data'] == null) continue;

      final normalized = _normalizeMkbLoginResponse(
        json,
        fallbackEmail: account.email,
      );
      final refreshed = UserModel.fromApiResponse(normalized);
      if (refreshed.email.isEmpty) continue;

      await LocalStorageService.saveOrUpdateUser(refreshed);
      return refreshed;
    }

    return null;
  }

  static Future<List<SubscriptionPackageOption>>
  fetchActiveSubscriptionPackages() async {
    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Session token not found. Please sign in again.');
    }

    Exception? lastError;
    for (final endpoint in _activeSubscriptionPackageEndpoints) {
      final uri = Uri.parse(endpoint);
      LoggerService.info('📦 [PACKAGES] URL=$uri');

      http.Response res;
      try {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        lastError = Exception('Unable to connect to package server: $e');
        continue;
      }

      LoggerService.info('📡 [PACKAGES] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) continue;
      if (res.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        lastError = Exception(
          'Unable to load packages (HTTP ${res.statusCode})',
        );
        continue;
      }

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Invalid package response from server.');
      }

      if (json['status'] != true) {
        throw Exception(
          (json['message'] ?? 'Unable to load packages').toString(),
        );
      }

      final data = json['data'];
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final rawItems = dataMap['items'] ?? dataMap['packages'] ?? data;
      if (rawItems is! List) return const [];

      return rawItems
          .whereType<Map>()
          .map(
            (item) => SubscriptionPackageOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((package) => package.packageId > 0 && package.title.isNotEmpty)
          .toList(growable: false);
    }

    throw lastError ?? Exception('Packages API route not found.');
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

  static Future<CreateUserResult> createManagedUser({
    required String fullName,
    required String email,
    required String password,
    String phone = '',
    String status = 'ACTIVE',
    int? roleId,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();
    final normalizedPhone = phone.trim();

    if (normalizedName.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'Full name is required',
      );
    }
    if (normalizedEmail.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'Email is required',
      );
    }
    if (normalizedPassword.length < 6) {
      return const CreateUserResult(
        success: false,
        message: 'Password must be at least 6 characters',
      );
    }

    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'Session token not found. Please sign in again.',
      );
    }

    final payload = <String, dynamic>{
      'FullName': normalizedName,
      'Email': normalizedEmail,
      'Phone': normalizedPhone,
      'password': normalizedPassword,
      'Status': status,
    };
    if (roleId != null) {
      payload['RoleID'] = roleId;
    }
    LoggerService.info(
      '👥 [ADD_USER] payload={FullName: $normalizedName, Email: $normalizedEmail, Phone: $normalizedPhone, Status: $status, RoleID: ${roleId ?? '(default)'}}',
    );

    CreateUserResult? lastFailure;
    for (final endpoint in _usersCreateEndpoints) {
      final uri = Uri.parse(endpoint);
      LoggerService.info('👥 [ADD_USER] URL=$uri');

      http.Response res;
      try {
        res = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        );
      } catch (_) {
        lastFailure = const CreateUserResult(
          success: false,
          message: 'Unable to connect to server',
        );
        continue;
      }

      LoggerService.info('📡 [ADD_USER] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) {
        continue;
      }

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          // ignore and fallback to status code
        }
      }

      if (json != null) {
        final ok = json['status'] == true;
        final message = (json['message'] ?? '').toString();
        final data = json['data'];
        final dataMap = data is Map<String, dynamic>
            ? data
            : <String, dynamic>{};
        final userIdRaw =
            dataMap['UserID'] ?? dataMap['id'] ?? dataMap['user_id'];
        final userId = int.tryParse(userIdRaw?.toString() ?? '');

        if (ok) {
          final created = CreateUserResult(
            success: true,
            message: message.isNotEmpty ? message : 'User added successfully',
            userId: userId,
          );
          return _ensureManagedUserRole(
            created: created,
            email: normalizedEmail,
            requestedRoleId: roleId,
          );
        }

        if (_isUsersWritePermissionError(
          statusCode: res.statusCode,
          message: message,
        )) {
          LoggerService.warn('👥 [ADD_USER] users.write missing on /users API');
          return const CreateUserResult(
            success: false,
            message:
                'You do not have permission to create team members (missing users.write). Please login with owner/admin account.',
          );
        }

        lastFailure = CreateUserResult(
          success: false,
          message: message.isNotEmpty ? message : 'Unable to add user',
        );
        continue;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final created = const CreateUserResult(
          success: true,
          message: 'User added successfully',
        );
        return _ensureManagedUserRole(
          created: created,
          email: normalizedEmail,
          requestedRoleId: roleId,
        );
      }

      if (res.statusCode == 403) {
        LoggerService.warn('👥 [ADD_USER] forbidden on /users API');
        lastFailure = const CreateUserResult(
          success: false,
          message:
              'You do not have permission to create team members (missing users.write). Please login with owner/admin account.',
        );
      } else if (res.statusCode == 401) {
        lastFailure = const CreateUserResult(
          success: false,
          message: 'You are not allowed to add users with this account.',
        );
      } else {
        lastFailure = CreateUserResult(
          success: false,
          message: 'Unable to add user (HTTP ${res.statusCode})',
        );
      }
    }

    return lastFailure ??
        const CreateUserResult(
          success: false,
          message: 'Users API route not found (404).',
        );
  }

  static Future<List<ManagedUserItem>> fetchManagedUsers() async {
    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.isEmpty) {
      throw Exception('Session token not found. Please sign in again.');
    }

    Exception? lastError;
    for (final endpoint in _usersCreateEndpoints) {
      final uri = Uri.parse(endpoint);
      LoggerService.info('👥 [TEAM_LIST] URL=$uri');

      http.Response res;
      try {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        lastError = Exception('Unable to connect to server: $e');
        continue;
      }

      LoggerService.info('📡 [TEAM_LIST] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) {
        continue;
      }

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Invalid response while loading users');
        }
      }
      if (json == null) {
        throw Exception('Empty response while loading users');
      }

      if (json['status'] != true) {
        throw Exception((json['message'] ?? 'Unable to load users').toString());
      }

      final data = json['data'];
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final itemsRaw = dataMap['items'];
      if (itemsRaw is! List) return const [];

      return itemsRaw
          .whereType<Map>()
          .map((e) => ManagedUserItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw lastError ?? Exception('Users API route not found (404).');
  }

  static Future<List<ManagedRoleItem>> fetchManageableRoles() async {
    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.isEmpty) {
      throw Exception('Session token not found. Please sign in again.');
    }

    Exception? lastError;
    for (final endpoint in _adminRolesEndpoints) {
      final uri = Uri.parse(endpoint);
      LoggerService.info('👥 [TEAM_ROLES] URL=$uri');

      http.Response res;
      try {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        lastError = Exception('Unable to connect to server: $e');
        continue;
      }

      LoggerService.info('📡 [TEAM_ROLES] ${res.statusCode} | ${res.body}');

      if (res.statusCode == 404) {
        continue;
      }
      if (res.statusCode == 403) {
        throw Exception(
          'You do not have permission to load roles (missing admin.roles.manage).',
        );
      }

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Invalid response while loading roles');
        }
      }
      if (json == null) {
        throw Exception('Empty response while loading roles');
      }

      if (json['status'] != true) {
        throw Exception((json['message'] ?? 'Unable to load roles').toString());
      }

      final data = json['data'];
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final itemsRaw = dataMap['items'];
      if (itemsRaw is! List) return const [];

      final roles = itemsRaw
          .whereType<Map>()
          .map((e) => ManagedRoleItem.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.roleId > 0 && r.roleCode != 'OWNER')
          .toList();
      roles.sort(
        (a, b) => a.roleName.toLowerCase().compareTo(b.roleName.toLowerCase()),
      );
      return roles;
    }

    throw lastError ?? Exception('Roles API route not found (404).');
  }

  static Future<CreateUserResult> updateManagedUser({
    required int userId,
    String? fullName,
    String? phone,
    String? status,
    int? roleId,
    String? password,
  }) async {
    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'Session token not found. Please sign in again.',
      );
    }

    final payload = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['FullName'] = fullName.trim();
    }
    if (phone != null) payload['Phone'] = phone.trim();
    if (status != null && status.trim().isNotEmpty) payload['Status'] = status;
    if (roleId != null) payload['RoleID'] = roleId;
    if (password != null && password.trim().isNotEmpty) {
      payload['password'] = password.trim();
    }

    if (payload.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'No changes to update',
      );
    }

    CreateUserResult? failure;
    for (final uri in _userByIdEndpoints(userId)) {
      LoggerService.info('👥 [TEAM_UPDATE] URL=$uri payload=$payload');
      http.Response res;
      try {
        res = await http.patch(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        );
      } catch (_) {
        failure = const CreateUserResult(
          success: false,
          message: 'Unable to connect to server',
        );
        continue;
      }

      LoggerService.info('📡 [TEAM_UPDATE] ${res.statusCode} | ${res.body}');
      if (res.statusCode == 404) continue;

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (json != null) {
        final ok = json['status'] == true;
        final message = (json['message'] ?? '').toString();
        if (ok) {
          return CreateUserResult(
            success: true,
            message: message.isNotEmpty ? message : 'User updated',
          );
        }
        failure = CreateUserResult(
          success: false,
          message: message.isNotEmpty ? message : 'Unable to update user',
        );
        continue;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const CreateUserResult(success: true, message: 'User updated');
      }

      failure = CreateUserResult(
        success: false,
        message: 'Unable to update user (HTTP ${res.statusCode})',
      );
    }

    return failure ??
        const CreateUserResult(
          success: false,
          message: 'Users API route not found (404).',
        );
  }

  static Future<CreateUserResult> deleteManagedUser({
    required int userId,
  }) async {
    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.isEmpty) {
      return const CreateUserResult(
        success: false,
        message: 'Session token not found. Please sign in again.',
      );
    }

    CreateUserResult? failure;
    for (final uri in _userByIdEndpoints(userId)) {
      LoggerService.info('👥 [TEAM_DELETE] URL=$uri');
      http.Response res;
      try {
        res = await http.delete(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (_) {
        failure = const CreateUserResult(
          success: false,
          message: 'Unable to connect to server',
        );
        continue;
      }

      LoggerService.info('📡 [TEAM_DELETE] ${res.statusCode} | ${res.body}');
      if (res.statusCode == 404) continue;

      Map<String, dynamic>? json;
      if (res.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (json != null) {
        final ok = json['status'] == true;
        final message = (json['message'] ?? '').toString();
        if (ok) {
          return CreateUserResult(
            success: true,
            message: message.isNotEmpty ? message : 'User deleted',
          );
        }
        failure = CreateUserResult(
          success: false,
          message: message.isNotEmpty ? message : 'Unable to delete user',
        );
        continue;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const CreateUserResult(success: true, message: 'User deleted');
      }
      failure = CreateUserResult(
        success: false,
        message: 'Unable to delete user (HTTP ${res.statusCode})',
      );
    }

    return failure ??
        const CreateUserResult(
          success: false,
          message: 'Users API route not found (404).',
        );
  }

  static bool _isUsersWritePermissionError({
    required int statusCode,
    required String message,
  }) {
    if (statusCode != 403) return false;
    final m = message.toLowerCase();
    return m.contains('users.write') || m.contains('forbidden');
  }

  static Future<CreateUserResult> _ensureManagedUserRole({
    required CreateUserResult created,
    required String email,
    required int? requestedRoleId,
  }) async {
    if (!created.success || requestedRoleId == null) return created;

    var targetUserId = created.userId;
    if (targetUserId == null || targetUserId <= 0) {
      targetUserId = await _findManagedUserIdByEmail(email);
    }

    if (targetUserId == null || targetUserId <= 0) {
      return CreateUserResult(
        success: false,
        userId: created.userId,
        message:
            'User created but role could not be verified (user id not found in team list). Please check users.read/users.write permissions.',
      );
    }

    final roleUpdate = await updateManagedUser(
      userId: targetUserId,
      roleId: requestedRoleId,
    );
    if (roleUpdate.success) {
      return CreateUserResult(
        success: true,
        userId: targetUserId,
        message: created.message,
      );
    }

    return CreateUserResult(
      success: false,
      userId: targetUserId,
      message: 'User created but role assignment failed: ${roleUpdate.message}',
    );
  }

  static Future<int?> _findManagedUserIdByEmail(String email) async {
    try {
      final target = email.trim().toLowerCase();
      final users = await fetchManagedUsers();
      for (final user in users) {
        if (user.email.trim().toLowerCase() == target) {
          return user.userId;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _normalizeMkbLoginResponse(
    Map<String, dynamic> raw, {
    required String fallbackEmail,
  }) {
    final rawData = raw['data'];
    final dataMap = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};
    final userRaw = dataMap['user'];
    final userMap = userRaw is Map<String, dynamic> ? userRaw : dataMap;

    final fullName = (userMap['FullName'] ?? userMap['full_name'] ?? '')
        .toString()
        .trim();
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final firstName = parts.isNotEmpty
        ? parts.first
        : (userMap['FirstName'] ?? userMap['first_name'] ?? '').toString();
    final lastName = parts.length > 1
        ? parts.sublist(1).join(' ')
        : (userMap['LastName'] ?? userMap['last_name'] ?? '').toString();
    final rolesRaw = dataMap['roles'] ?? dataMap['Roles'];
    final permissionsRaw = dataMap['permissions'] ?? dataMap['Permissions'];

    return {
      'status': raw['status'] == true,
      'message': (raw['message'] ?? '').toString(),
      'data': {
        'id': (userMap['UserID'] ?? userMap['id'] ?? '').toString(),
        'email': (userMap['Email'] ?? userMap['email'] ?? fallbackEmail)
            .toString(),
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName.isNotEmpty
            ? fullName
            : [
                firstName,
                lastName,
              ].where((e) => e.trim().isNotEmpty).join(' ').trim(),
        'image_url': (userMap['image_url'] ?? '').toString(),
        'is_login': 1,
        'roles': rolesRaw is List ? rolesRaw : const [],
        'permissions': permissionsRaw is List ? permissionsRaw : const [],
        'plan_status': dataMap['plan_status'] ?? userMap['plan_status'],
        'expiry': dataMap['expiry'] ?? userMap['expiry'],
        'subscription': dataMap['subscription'] ?? userMap['subscription'],
      },
    };
  }

  static String? _extractMkbToken(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      final token = data['token']?.toString().trim() ?? '';
      if (token.isNotEmpty) return token;
    }
    return null;
  }

  static int? _extractMkbTenantId(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is! Map<String, dynamic>) return null;
    final userRaw = data['user'];
    final user = userRaw is Map<String, dynamic> ? userRaw : data;
    final id = int.tryParse(
      (user['TenantID'] ?? user['tenant_id'] ?? '').toString(),
    );
    if (id == null || id <= 0) return null;
    return id;
  }

  static Future<int?> resolveTenantIdForCurrentSession() async {
    final cached = await LocalStorageService.loadTenantIdForLastUsedUser();
    if (cached != null && cached > 0) return cached;

    final token = await LocalStorageService.loadAuthTokenForLastUsedUser();
    if (token == null || token.trim().isEmpty) return null;

    final lastUser = await LocalStorageService.loadLastUsedUser();
    final email = lastUser?.email ?? '';

    for (final endpoint in _meEndpoints) {
      final uri = Uri.parse(endpoint);
      http.Response res;
      try {
        res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        );
      } catch (_) {
        continue;
      }

      if (res.statusCode == 404) continue;
      if (res.statusCode < 200 || res.statusCode >= 300) continue;
      if (res.body.trim().isEmpty) continue;

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (json['status'] != true) continue;

      final dataRaw = json['data'];
      if (dataRaw is! Map<String, dynamic>) continue;
      final tenantId = int.tryParse(
        (dataRaw['TenantID'] ?? dataRaw['tenant_id'] ?? '').toString(),
      );
      if (tenantId == null || tenantId <= 0) continue;

      if (email.trim().isNotEmpty) {
        await LocalStorageService.saveTenantId(
          email: email,
          tenantId: tenantId,
        );
      }
      return tenantId;
    }

    return null;
  }

  static String _resolveLoginFailureMessage(Map<String, dynamic> json) {
    final explicitMessage = (json['message'] ?? json['error'] ?? '')
        .toString()
        .trim();
    if (_looksInactiveMessage(explicitMessage)) {
      return 'Your account is inactive. Please contact your administrator.';
    }

    final rawData = json['data'];
    final dataMap = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};
    final userRaw = dataMap['user'];
    final userMap = userRaw is Map<String, dynamic> ? userRaw : dataMap;

    final statusCandidates = <dynamic>[
      json['Status'],
      json['status_text'],
      json['status_code'],
      dataMap['Status'],
      dataMap['status'],
      dataMap['status_text'],
      dataMap['status_code'],
      dataMap['is_active'],
      dataMap['active'],
      userMap['Status'],
      userMap['status'],
      userMap['status_text'],
      userMap['status_code'],
      userMap['is_active'],
      userMap['active'],
    ];

    for (final candidate in statusCandidates) {
      if (_statusMeansInactive(candidate)) {
        return 'Your account is inactive. Please contact your administrator.';
      }
    }

    if (explicitMessage.isNotEmpty) return explicitMessage;
    return 'Invalid email or password';
  }

  static bool _looksInactiveMessage(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('inactive') ||
        normalized.contains('disabled') ||
        normalized.contains('deactivated') ||
        normalized.contains('suspended') ||
        normalized.contains('not active');
  }

  static bool _statusMeansInactive(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value == false;

    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;

    return normalized == 'inactive' ||
        normalized == 'disabled' ||
        normalized == 'deactivated' ||
        normalized == 'suspended' ||
        normalized == '0' ||
        normalized == 'false' ||
        normalized == 'not active';
  }

  static List<Uri> _userByIdEndpoints(int userId) {
    return _usersCreateEndpoints
        .map((base) => Uri.parse('$base/$userId'))
        .toList();
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

class AuthRegisterResult {
  final bool success;
  final String message;

  const AuthRegisterResult({required this.success, required this.message});
}

class CreateUserResult {
  final bool success;
  final String message;
  final int? userId;

  const CreateUserResult({
    required this.success,
    required this.message,
    this.userId,
  });
}

class ManagedRoleItem {
  final int roleId;
  final String roleCode;
  final String roleName;

  const ManagedRoleItem({
    required this.roleId,
    required this.roleCode,
    required this.roleName,
  });

  factory ManagedRoleItem.fromJson(Map<String, dynamic> json) {
    final code = (json['RoleCode'] ?? json['role_code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final name = (json['RoleName'] ?? json['role_name'] ?? code)
        .toString()
        .trim();

    return ManagedRoleItem(
      roleId:
          int.tryParse((json['RoleID'] ?? json['role_id'] ?? 0).toString()) ??
          0,
      roleCode: code,
      roleName: name.isNotEmpty ? name : code,
    );
  }
}

class ManagedUserItem {
  final int userId;
  final int tenantId;
  final int? roleId;
  final String? roleCode;
  final String? roleName;
  final String email;
  final String? phone;
  final String fullName;
  final String status;
  final String? lastLoginAt;
  final String? createdAt;
  final String? updatedAt;

  const ManagedUserItem({
    required this.userId,
    required this.tenantId,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.status,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ManagedUserItem.fromJson(Map<String, dynamic> json) {
    return ManagedUserItem(
      userId: int.tryParse((json['UserID'] ?? json['id'] ?? 0).toString()) ?? 0,
      tenantId:
          int.tryParse(
            (json['TenantID'] ?? json['tenant_id'] ?? 0).toString(),
          ) ??
          0,
      roleId: int.tryParse(
        (json['RoleID'] ?? json['role_id'] ?? json['roleId'] ?? '').toString(),
      ),
      roleCode:
          (json['RoleCode'] ?? json['role_code'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (json['RoleCode'] ?? json['role_code']).toString(),
      roleName:
          (json['RoleName'] ?? json['role_name'] ?? json['role'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (json['RoleName'] ?? json['role_name'] ?? json['role']).toString(),
      email: (json['Email'] ?? json['email'] ?? '').toString(),
      phone: json['Phone']?.toString(),
      fullName: (json['FullName'] ?? json['full_name'] ?? '').toString(),
      status: (json['Status'] ?? '').toString(),
      lastLoginAt: json['LastLoginAt']?.toString(),
      createdAt: json['CreatedAt']?.toString(),
      updatedAt: json['UpdatedAt']?.toString(),
    );
  }
}

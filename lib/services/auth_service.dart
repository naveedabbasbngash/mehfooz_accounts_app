import 'dart:convert';
import 'dart:ui';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../model/user_model.dart';
import 'local_storage.dart';
import 'logging/logger_service.dart';

class AuthService {
  static const List<String> scopes = ['email', 'profile', 'openid'];

  static const String androidClientId = '800232142357-rvl2rpvongbct6vtafecct2rmva1vng9.apps.googleusercontent.com';
  static const String iosClientId = '800232142357-2u8et6b02e4s4jkl6s9du6o4i0bpmtc9.apps.googleusercontent.com';

  static Future<UserModel?> loginWithGoogle() async {
    LoggerService.info("🔵 Google login started");

    try {
      final signIn = GoogleSignIn.instance;

      await signIn.initialize(
        clientId: iosClientId,
        serverClientId: androidClientId,
      );

      final GoogleSignInAccount? user = await signIn.authenticate();

      if (user == null) {
        LoggerService.warn("⚠️ User cancelled login");
        return null;
      }

      final headers = await user.authorizationClient.authorizationHeaders(scopes);
      // final accessToken = headers['Authorization']?.replaceFirst('Bearer ', '');

      final email = user.email;
      final name = user.displayName ?? '';
      final imageUrl = user.photoUrl ?? '';

      LoggerService.info("✅ Google login successful for $email");

      final response = await http.post(
        Uri.parse("https://kheloaurjeeto.net/mahfooz_accounts/api/login"),
        body: {
          "email": email,
          "image_url": imageUrl,
        },
      );

      LoggerService.debug("🌐 API response (${response.statusCode}): ${response.body}");

      if (response.statusCode != 200) {
        // LoggerService.error("❌ API error", error: response.body);
        return null;
      }

      final json = jsonDecode(response.body);
      final status = json['status'] == true;
      final message = json['message'] ?? 'Unknown message';

      if (!status || json['data'] == null) {
        LoggerService.warn("⚠ Login failed: $message");
        await signIn.disconnect();
        await signIn.signOut();

        return UserModel(
          status: false,
          message: message,
          id: '',
          email: email,
          firstName: '',
          lastName: '',
          fullName: name,
          imageUrl: imageUrl,
          isLogin: 0,
        );
      }

      final userModel = UserModel.fromApiResponse(json);
      await LocalStorageService.saveUser(userModel);
      LoggerService.info("🎉 LOGIN COMPLETE");
      return userModel;
    } catch (e, s) {
      // LoggerService.error("❌ Login failed", error: e, stackTrace: s);
      return null;
    }
  }

  static Future<UserModel?> loadSavedUser() async {
    final user = await LocalStorageService.loadLatestUser();
    if (user != null) {
      LoggerService.info("🔁 Auto-login user: ${user.email}");
    }
    return user;
  }

  static Future<void> logout({VoidCallback? onLoggedOut}) async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}

    await GoogleSignIn.instance.signOut();
    await LocalStorageService.clearAllUsers();

    LoggerService.info("👋 Logged out successfully");

    if (onLoggedOut != null) onLoggedOut();
  }}
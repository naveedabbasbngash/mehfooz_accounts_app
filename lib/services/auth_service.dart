import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../model/user_model.dart';
import 'local_storage.dart';
import 'logging/logger_service.dart';

class AuthService {
  static const List<String> scopes = ['email', 'profile', 'openid'];

  static const String androidClientId =
      '800232142357-rvl2rpvongbct6vtafecct2rmva1vng9.apps.googleusercontent.com';
  static const String iosClientId =
      '800232142357-2u8et6b02e4s4jkl6s9du6o4i0bpmtc9.apps.googleusercontent.com';

  // ============================================================
  // LOGIN WITH GOOGLE
  // ============================================================
  static Future<UserModel?> loginWithGoogle() async {
    LoggerService.info("🔵 Google login started");

    try {
      final signIn = GoogleSignIn.instance;

      await signIn.initialize(
        clientId: iosClientId,
        serverClientId: androidClientId,
      );

      final GoogleSignInAccount? googleUser =
      await signIn.authenticate();

      if (googleUser == null) {
        LoggerService.warn("⚠️ User cancelled login");
        return null;
      }

      // 🔑 STEP 1: Google auth tokens
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 🔑 STEP 2: Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 🔥 STEP 3: SIGN IN TO FIREBASE (THIS WAS MISSING)
      final firebaseUser =
      await FirebaseAuth.instance.signInWithCredential(credential);

      LoggerService.info(
        "🔥 Firebase user signed in: ${firebaseUser.user?.email}",
      );

      // ========================================================
      // YOUR EXISTING BACKEND LOGIN (KEEP AS-IS)
      // ========================================================
      final email = googleUser.email;
      final imageUrl = googleUser.photoUrl ?? '';

      final response = await http.post(
        Uri.parse(
          "https://kheloaurjeeto.net/mahfooz_accounts/api/login",
        ),
        body: {
          "email": email,
          "image_url": imageUrl,
        },
      );

      if (response.statusCode != 200) {
        LoggerService.warn("❌ API error: ${response.statusCode}");
        return null;
      }

      final json = jsonDecode(response.body);

      if (json['status'] != true || json['data'] == null) {
        LoggerService.warn("⚠ Login failed: ${json['message']}");

        await FirebaseAuth.instance.signOut();
        await signIn.signOut();
        return null;
      }

      final userModel = UserModel.fromApiResponse(json);

      await LocalStorageService.saveUser(userModel);

      LoggerService.info(
        "🎉 LOGIN COMPLETE | canSync=${userModel.planStatus?.canSync}",
      );

      return userModel;
    } catch (e, s) {
      LoggerService.warn("❌ Login failed: $e");
      return null;
    }
  }
  // ============================================================
  // AUTO LOGIN
  // ============================================================
  static Future<UserModel?> loadSavedUser() async {
    final user = await LocalStorageService.loadLatestUser();
    if (user != null) {
      LoggerService.info(
        "🔁 Auto-login user: ${user.email} | canSync=${user.planStatus?.canSync}",
      );
    }
    return user;
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  static Future<void> logout({VoidCallback? onLoggedOut}) async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}

    await GoogleSignIn.instance.signOut();

    // ✅ Clear all saved users
    await LocalStorageService.clearAllUsers();

    LoggerService.info("👋 Logged out successfully");

    if (onLoggedOut != null) onLoggedOut();
  }
}
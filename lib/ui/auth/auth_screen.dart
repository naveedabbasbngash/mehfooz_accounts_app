// lib/ui/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/logging/logger_service.dart';
import '../home/home_wrapper.dart';
import 'login_failure_screen.dart';

class AuthScreen extends StatefulWidget {
  final GlobalKey<SliderDrawerState> sliderDrawerKey;

  const AuthScreen({
    super.key,
    required this.sliderDrawerKey,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    LoggerService.debug("[UI][AuthScreen] Starting login...");

    final UserModel? user = await AuthService.loginWithGoogle();

    setState(() => _isLoading = false);

    if (user == null) {
      LoggerService.warn("[UI][AuthScreen] Login failed");
      setState(() => _error = "Login failed. Please try again.");
      return;
    }

    if (!user.status) {
      LoggerService.warn("[UI][AuthScreen] Login rejected: ${user.message}");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginFailureScreen(
            title: "Login Failed",
            message: user.message,
            user: user,
            sliderDrawerKey: widget.sliderDrawerKey,   // ← REQUIRED FIX
          ),
        ),
      );      return;
    }

    LoggerService.info("[UI][AuthScreen] Login success → Home");

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeWrapper(
          user: user,
          sliderDrawerKey: widget.sliderDrawerKey,   // ✅ FIXED
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mahfooz – Login"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text("Signing in..."),
              ],

              if (!_isLoading) ...[
                const Text(
                  "Sign in to continue",
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _handleGoogleLogin,
                  icon: const Icon(Icons.login),
                  label: const Text("Sign in with Google"),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
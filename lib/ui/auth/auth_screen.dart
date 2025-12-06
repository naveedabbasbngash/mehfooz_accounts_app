// lib/ui/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../model/user_model.dart';
import '../../viewmodel/auth/auth_view_model.dart';
import '../home/home_wrapper.dart';
import 'login_failure_screen.dart';

class AuthScreen extends StatelessWidget {
  final GlobalKey<SliderDrawerState> sliderDrawerKey;

  const AuthScreen({
    super.key,
    required this.sliderDrawerKey,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: _AuthScreenBody(sliderDrawerKey: sliderDrawerKey),
    );
  }
}

class _AuthScreenBody extends StatefulWidget {
  final GlobalKey<SliderDrawerState> sliderDrawerKey;

  const _AuthScreenBody({
    required this.sliderDrawerKey,
  });

  @override
  State<_AuthScreenBody> createState() => _AuthScreenBodyState();
}

class _AuthScreenBodyState extends State<_AuthScreenBody> {
  Future<void> _handleGoogleLogin() async {
    final vm = context.read<AuthViewModel>();

    final UserModel? user = await vm.loginWithGoogle();

    if (user == null) {
      // General failure (network, exception, etc.)
      return;
    }

    if (!user.status) {
      // Show failure screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginFailureScreen(
            title: "Login Failed",
            message: user.message,
            user: user,
            sliderDrawerKey: widget.sliderDrawerKey,
          ),
        ),
      );
      return;
    }

    // Success -> go Home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeWrapper(
          user: user,
          sliderDrawerKey: widget.sliderDrawerKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
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
              if (vm.isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text("Signing in..."),
              ] else ...[
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
              if (vm.errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  vm.errorMessage!,
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
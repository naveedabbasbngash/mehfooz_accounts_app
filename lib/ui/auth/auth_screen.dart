// lib/ui/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:mehfooz_accounts_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../model/user_model.dart';
import '../../viewmodel/auth/auth_view_model.dart';
import '../../main.dart';
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
      child: const _AuthBody(),
    );
  }
}

class _AuthBody extends StatefulWidget {
  const _AuthBody();

  @override
  State<_AuthBody> createState() => _AuthBodyState();
}

class _AuthBodyState extends State<_AuthBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // GOOGLE LOGIN HANDLER (UNCHANGED)
  // ---------------------------------------------------------------------------
  Future<void> _handleGoogleLogin() async {
    final vm = context.read<AuthViewModel>();
    final UserModel? user = await vm.loginWithGoogle();

    if (user == null) return;

    if (!user.status) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginFailureScreen(
            title: "Login Failed",
            message: user.message,
            user: user,
            sliderDrawerKey: GlobalKey<SliderDrawerState>(),
          ),
        ),
      );
      return;
    }

    context.findAncestorStateOfType<MahfoozAppState>()?.resetUser();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final theme = Theme.of(context);

    final primary = AppColors.darkgreen;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: primary.withOpacity(0.95),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ICON
                      Icon(
                        Icons.account_circle_outlined,
                        size: 64,
                        color: primary,
                      ),

                      const SizedBox(height: 16),

                      // TITLE
                      Text(
                        "Welcome to Mahfooz Accounts",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SUBTITLE
                      Text(
                        "Sign in with your Google account to continue. "
                            "We’ll verify your subscription & activation automatically.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                          vm.isLoading ? null : _handleGoogleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: vm.isLoading
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Signing in…",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )
                              : const Text(
                            "Continue with Google",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // ERROR CHIP
                      if (vm.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18,
                                  color: theme.colorScheme.error),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  vm.errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),

                      // FOOTER TEXT
                      Text(
                        "Returning users skip this screen automatically.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onSurfaceVariant),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "App version v1",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
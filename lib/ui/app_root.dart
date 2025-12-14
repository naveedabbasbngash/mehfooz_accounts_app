import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../model/user_model.dart';
import 'auth/auth_screen.dart';
import 'home/home_wrapper.dart';

class AppRoot extends StatelessWidget {
  final UserModel? user;
  final bool userDbExists;
  final GlobalKey<SliderDrawerState> sliderDrawerKey;

  const AppRoot({
    super.key,
    required this.user,
    required this.userDbExists,
    required this.sliderDrawerKey,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = user != null && user!.isLogin == 1;

    // ────────────────────────────────────────────────────────────────
    // NOT LOGGED IN → SHOW LOGIN SCREEN
    // ────────────────────────────────────────────────────────────────
    if (!isLoggedIn) {
      return AuthScreen(sliderDrawerKey: sliderDrawerKey);
    }

    // ────────────────────────────────────────────────────────────────
    // LOGGED IN → GO TO HOME WRAPPER
    // ────────────────────────────────────────────────────────────────
    return HomeWrapper(
      user: user!,
      sliderDrawerKey: sliderDrawerKey,

      // If DB exists → start on HOME. Otherwise → start on PROFILE.
      initialTabIndex: userDbExists ? 0 : 3,

      // If DB missing → force restricted mode ON.
    );
  }
}
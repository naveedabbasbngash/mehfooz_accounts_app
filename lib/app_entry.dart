import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_session_controller.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/home/home_wrapper.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionController>();

    if (session.isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final user = session.user;
    final isLoggedIn = user != null && user.isLogin == 1;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn
          ? HomeWrapper(
        user: user,
        sliderDrawerKey: GlobalKey<SliderDrawerState>(),
        initialTabIndex: session.userDbExists ? 0 : 3,
      )
          : AuthScreen(
        sliderDrawerKey: GlobalKey<SliderDrawerState>(),
      ),
    );
  }
}
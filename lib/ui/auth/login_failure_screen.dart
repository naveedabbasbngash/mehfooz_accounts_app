import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import '../../model/user_model.dart';
import 'auth_screen.dart';

class LoginFailureScreen extends StatelessWidget {
  final String title;
  final String message;
  final UserModel? user;
  final GlobalKey<SliderDrawerState> sliderDrawerKey;   // ✅ ADDED

  const LoginFailureScreen({
    Key? key,
    required this.title,
    required this.message,
    this.user,
    required this.sliderDrawerKey,   // ✅ REQUIRED
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFFCDD2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    if (user != null && user!.email.isNotEmpty) ...[
                      Text("👤 ${user!.fullName}", style: const TextStyle(fontSize: 16)),
                      Text("📧 ${user!.email}", style: const TextStyle(fontSize: 16)),
                    ],

                    const SizedBox(height: 30),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Contact Support"),
                            content: const Text("📞 +92-300-1234567\n📧 support@mahfooz.com"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("OK"),
                              )
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent),
                      label: const Text("Contact Support"),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(
                              sliderDrawerKey: sliderDrawerKey,   // ✔ FIXED
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text("Back to Login"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
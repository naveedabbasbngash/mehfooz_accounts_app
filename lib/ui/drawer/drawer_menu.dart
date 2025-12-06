import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../main.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart'; // <-- IMPORTANT

class DrawerMenu extends StatelessWidget {
  final Function(String) onItemClick;
  final GlobalKey<SliderDrawerState> drawerKey;
  final int currentPageIndex;

  final UserModel user;

  const DrawerMenu({
    super.key,
    required this.onItemClick,
    required this.drawerKey,
    required this.currentPageIndex,
    required this.user,
  });

  void _logAction(String title) {
    print("\n============================");
    print("📌 Drawer Menu Clicked: $title");
    print("👤 User Full Name: ${user.fullName}");
    print("🪪 First Name: ${user.firstName}");
    print("🪪 Last Name: ${user.lastName}");
    print("📧 User Email: ${user.email}");
    print("🖼️ User Image URL: ${user.imageUrl}");
    print("🔐 is_login: ${user.isLogin}");
    print("============================\n");
  }

  Future<void> _handleLogout(BuildContext context) async {
    _logAction("Logout");
    await AuthService.logout();

    drawerKey.currentState?.closeSlider();

    Future.delayed(const Duration(milliseconds: 250), () {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    });
  }

  Widget _menuItem({
    required String title,
    required IconData icon,
    required int index,
    required BuildContext context,
  }) {
    final bool selected = currentPageIndex == index;

    return Container(
      decoration: selected
          ? BoxDecoration(
        color: AppColors.darkgreen.withOpacity(0.20),   // ⭐ LIGHT GREEN HIGHLIGHT
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          _logAction(title);
          onItemClick(title);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValidImage =
        user.imageUrl.isNotEmpty && user.imageUrl.startsWith("http");

    return Container(
      color: AppColors.darkgreen,     // ⭐ MATCHES BOTTOM NAVIGATION
      padding: const EdgeInsets.only(top: 50, left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐ USER PROFILE
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            backgroundImage: hasValidImage ? NetworkImage(user.imageUrl) : null,
            child: !hasValidImage
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),

          const SizedBox(height: 10),

          Text(
            user.fullName.isNotEmpty
                ? user.fullName
                : (user.firstName.isNotEmpty
                ? "${user.firstName} ${user.lastName}".trim()
                : "User"),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),

          Text(
            user.email,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),

          const SizedBox(height: 30),

          _menuItem(
            title: "Home",
            icon: Icons.home,
            index: 0,
            context: context,
          ),
          _menuItem(
            title: "Transaction",
            icon: Icons.search,
            index: 1,
            context: context,
          ),
          _menuItem(
            title: "Reports",
            icon: Icons.bar_chart,
            index: 2,
            context: context,
          ),
          _menuItem(
            title: "Profile",
            icon: Icons.person,
            index: 3,
            context: context,
          ),

          const Divider(color: Colors.white54),

          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text(
              "Settings",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              _logAction("Settings");
              onItemClick("Settings");
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              await AuthService.logout();
              context.findAncestorStateOfType<MahfoozAppState>()?.resetUser();
            },
          ),
        ],
      ),
    );
  }
}
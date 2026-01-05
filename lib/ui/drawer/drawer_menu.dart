import 'package:flutter/material.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';

import '../../main.dart';
import '../../model/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class DrawerMenu extends StatelessWidget {
  final Function(int) onItemClick;
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
    print("👤 User Email: ${user.email}");
    print("🔐 is_login: ${user.isLogin}");
    print("============================\n");
  }

  Widget _menuItem({
    required String title,
    required IconData icon,
    required int index,
    required BuildContext context,
  }) {
    final bool selected = currentPageIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
          BoxShadow(
            color: Colors.white.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Row(
        children: [
          // ⭐ LEFT INDICATOR BAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(
                icon,
                color: selected ? Colors.white : Colors.white70,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              onTap: () {
                _logAction(title);
                onItemClick(index);
                drawerKey.currentState?.closeSlider();
              },
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkgreen,
      padding: const EdgeInsets.only(top: 50, left: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐ BRAND HEADER (SINGLE CARD – NO DOUBLE RECTANGLE)
// ================= BRAND HEADER =================
          Center(
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Mahfooz Accounts",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

// ⭐ CLEAR SEPARATION (THIS IS THE KEY)
          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.only(right: 20),
            height: 1,
            color: Colors.white.withOpacity(0.25),
          ),

          const SizedBox(height: 16),
// ================= END HEADER =================

          const SizedBox(height: 15),
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

          // ⭐ LOGOUT ONLY
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text(
              "Logout",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              _logAction("Logout");
              await AuthService.logout();
              context.findAncestorStateOfType<MahfoozAppState>()?.resetUser();
            },
          ),
        ],
      ),
    );
  }
}
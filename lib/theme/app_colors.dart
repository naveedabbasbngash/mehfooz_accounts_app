import 'package:flutter/material.dart';

class AppColors {
  // ============================================================
  // 🌈 PRIMARY BRAND COLORS  (same as your original)
  // ============================================================
  static const Color primary = Color(0xFF09550C); // Deep purple
  static const Color accent  = Color(0xFF9575CD);
  static const Color app_bg  = Color(0xFFFFFFFF);
  static const Color emptyBackground = Color(0xFFF7F8FA);

  // ============================================================
  // 🌈 SCREEN-SPECIFIC COLORS  (kept as-is for now)
  // ============================================================
  static const Color homeColor    = Color(0xFFFFFFFF);
  static const Color searchColor  = Color(0xFFFFFFFF);
  static const Color reportsColor = Color(0xFFFFFFFF);
  static const Color profileColor = Color(0xFFFFFFFF);

  // ============================================================
  // 🌈 DRAWER COLORS   (same as your version)
  // ============================================================
  static const Color drawerBackground = Color(0xFF512DA8);
  static const Color drawerHighlight  = Color(0xFF7E57C2);

  // ============================================================
  // 🌈 BOTTOM NAVIGATION COLORS  (same names)
  // ============================================================
  static const Color navBarBackground = Color(0xFF673AB7);
  static const Color navBarIcon       = Colors.white;
  static const Color nav_text         = Color(0xFF000000);

  /// Your custom dark green used for nav, etc.
  static const Color darkgreen        = Color(0xFF09550C);

  // ============================================================
  // 🌈 TEXT COLORS
  // ============================================================
  static const Color textDark  = Color(0xFF212121);
  static const Color textLight = Colors.black;

  /// Muted / secondary text (for hints, captions, etc.)
  static const Color textMuted = Color(0xFF757575);

  // ============================================================
  // 🌈 COMMON STATUS COLORS
  // ============================================================
  static const Color success = Colors.green;
  static const Color error   = Colors.red;
  static const Color warning = Colors.orange;

  // ============================================================
  // 🌈 CARD + SURFACE SYSTEM (NEW, used in your widgets)
  // ============================================================
  /// Default card background (e.g., summary cards)
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// Soft shadow color for cards
  static const Color cardShadow = Color(0x14000000);

  /// Divider / border lines inside cards & lists
  static const Color divider = Color(0xFFE0E0E0);

  /// Light highlight / tag background (chips, badges)
  static const Color highlight = Color(0xFFF4ECFF);

  // ============================================================
  // 🌈 GREY UTILS (optional – handy for backgrounds)
  // ============================================================
  static const Color greyLight = Color(0xFFF6F6F6);
  static const Color grey      = Color(0xFFE0E0E0);
  static const Color greyDark  = Color(0xFF9E9E9E);


}
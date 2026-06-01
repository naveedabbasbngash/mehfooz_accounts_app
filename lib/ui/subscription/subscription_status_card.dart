import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/user_model.dart';

class SubscriptionStatusCard extends StatelessWidget {
  final UserModel user;
  final bool compact;
  final bool onDark;
  final VoidCallback? onRenew;
  final String actionLabel;

  const SubscriptionStatusCard({
    super.key,
    required this.user,
    this.compact = false,
    this.onDark = false,
    this.onRenew,
    this.actionLabel = 'Renew Package',
  });

  @override
  Widget build(BuildContext context) {
    final style = _SubscriptionStyle.fromUser(user);
    final plan = user.subscription?.planTitle.trim();
    final days = user.expiry?.remainingDays;
    final endDate = _formatDate(user.subscription?.endDate);
    final subtitle = _subtitle(style, plan, days, endDate);
    final remainingValue = style.code == 'LEGACY'
        ? 'Included'
        : days == null
        ? 'N/A'
        : '$days days';
    final shouldShowAction =
        onRenew != null &&
        (style.code == 'EXPIRED' ||
            style.code == 'SUSPENDED' ||
            style.code == 'CANCELLED');

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: onDark ? 0.18 : 1),
              Colors.white.withValues(alpha: onDark ? 0.08 : 0.94),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: 0.18)
                : style.primary.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            _StatusMark(style: style, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onDark ? Colors.white : const Color(0xFF102132),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onDark
                          ? Colors.white.withValues(alpha: 0.72)
                          : const Color(0xFF607086),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: style.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -42,
              child: _GlowCircle(size: 150, alpha: 0.14),
            ),
            Positioned(
              left: -48,
              bottom: -64,
              child: _GlowCircle(size: 190, alpha: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusMark(style: style, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.eyebrow,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              style.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SubscriptionMiniBadge(user: user, onDark: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Plan',
                          value: plan == null || plan.isEmpty
                              ? 'Package'
                              : plan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'Remaining',
                          value: remainingValue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricTile(
                          label: 'Renewal',
                          value: endDate ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  if (shouldShowAction) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRenew,
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: Text(actionLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: style.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(
    _SubscriptionStyle style,
    String? plan,
    int? days,
    String? endDate,
  ) {
    final planLabel = plan == null || plan.isEmpty ? 'your package' : plan;
    if (style.code == 'TRIAL') {
      return days == null
          ? 'Your trial package is active.'
          : 'Your $planLabel trial is active with $days days remaining.';
    }
    if (style.code == 'ACTIVE') {
      return endDate == null
          ? 'Your $planLabel package is active.'
          : 'Your $planLabel package is active until $endDate.';
    }
    if (style.code == 'LEGACY') {
      return 'Your existing account access is active while package billing is being introduced.';
    }
    if (style.code == 'EXPIRED') {
      return 'Your package has expired. Renew to restore premium access.';
    }
    if (style.code == 'SUSPENDED') {
      return 'Your package is suspended. Contact support to restore access.';
    }
    if (style.code == 'CANCELLED') {
      return 'Your package is cancelled. Choose a package to continue.';
    }
    return 'Package status is not available yet.';
  }

  static String? _formatDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;
    return DateFormat('dd MMM yyyy').format(parsed);
  }
}

class SubscriptionMiniBadge extends StatelessWidget {
  final UserModel? user;
  final bool onDark;

  const SubscriptionMiniBadge({
    super.key,
    required this.user,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    if (currentUser == null || !currentUser.hasPackageStatus) {
      return const SizedBox.shrink();
    }
    final style = _SubscriptionStyle.fromUser(currentUser);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : style.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.22)
              : style.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: 12,
            color: onDark ? Colors.white : style.primary,
          ),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              color: onDark ? Colors.white : style.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  final _SubscriptionStyle style;
  final double size;

  const _StatusMark({required this.style, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Icon(style.icon, color: Colors.white, size: size * 0.52),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double alpha;

  const _GlowCircle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _SubscriptionStyle {
  final String code;
  final String label;
  final String eyebrow;
  final IconData icon;
  final Color primary;
  final List<Color> gradient;

  const _SubscriptionStyle({
    required this.code,
    required this.label,
    required this.eyebrow,
    required this.icon,
    required this.primary,
    required this.gradient,
  });

  factory _SubscriptionStyle.fromUser(UserModel user) {
    final code = user.packageStatusCode;
    final label = user.packageStatusText;
    switch (code) {
      case 'TRIAL':
        return _SubscriptionStyle(
          code: code,
          label: label,
          eyebrow: 'TRIAL ACCESS',
          icon: Icons.hourglass_top_rounded,
          primary: const Color(0xFFB7791F),
          gradient: const [
            Color(0xFFB7791F),
            Color(0xFFE0A338),
            Color(0xFF8A5A12),
          ],
        );
      case 'ACTIVE':
      case 'LEGACY':
        return _SubscriptionStyle(
          code: code,
          label: label,
          eyebrow: code == 'LEGACY' ? 'ACCOUNT ACCESS' : 'ACTIVE PACKAGE',
          icon: Icons.verified_rounded,
          primary: const Color(0xFF0E7A5F),
          gradient: const [
            Color(0xFF0E7A5F),
            Color(0xFF159A7A),
            Color(0xFF064B3D),
          ],
        );
      case 'EXPIRED':
        return _SubscriptionStyle(
          code: code,
          label: label,
          eyebrow: 'ACTION REQUIRED',
          icon: Icons.lock_clock_rounded,
          primary: const Color(0xFFB42318),
          gradient: const [
            Color(0xFFB42318),
            Color(0xFFD9483B),
            Color(0xFF7A1C15),
          ],
        );
      case 'SUSPENDED':
      case 'CANCELLED':
        return _SubscriptionStyle(
          code: code,
          label: label,
          eyebrow: 'ACCESS LIMITED',
          icon: Icons.block_rounded,
          primary: const Color(0xFF6B7280),
          gradient: const [
            Color(0xFF4B5563),
            Color(0xFF6B7280),
            Color(0xFF1F2937),
          ],
        );
      default:
        return _SubscriptionStyle(
          code: code,
          label: label,
          eyebrow: 'PACKAGE STATUS',
          icon: Icons.workspace_premium_rounded,
          primary: const Color(0xFF1862A3),
          gradient: const [
            Color(0xFF1E72C8),
            Color(0xFF1862A3),
            Color(0xFF0D4C81),
          ],
        );
    }
  }
}

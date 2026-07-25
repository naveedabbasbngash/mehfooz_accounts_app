import 'package:flutter/material.dart';

import '../../../data/local/database_manager.dart';
import '../../../model/user_model.dart';
import '../../../services/local_storage.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../subscription/subscription_status_card.dart';

const _kHomeBrandBlue = Color(0xFF1862A3);
const _kHomeBrandBlueDark = Color(0xFF0D4C81);

class HomeHeader extends StatelessWidget {
  final HomeViewModel vm;
  final VoidCallback onChangeCompany;

  const HomeHeader({
    super.key,
    required this.vm,
    required this.onChangeCompany,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeHeaderData>(
      future: _loadHeaderData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final companyName = data?.companyName ?? "Mahfooz Accounts";
        final displayName = companyName.trim().isEmpty
            ? "Mahfooz Accounts MKB"
            : companyName;
        final email = data?.user?.email.trim() ?? '';
        final roleLabel = _roleLabel(data?.user);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E72C8), _kHomeBrandBlue, _kHomeBrandBlueDark],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x261862A3),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top: workspace label + switch button ──
              Row(
                children: [
                  Text(
                    'WORKSPACE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onChangeCompany,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Switch',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 8),
              // ── Main: app icon + welcome + company name ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Color(0xFFB8D8F5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: SubscriptionMiniBadge(
                              user: data?.user,
                              onDark: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_HomeHeaderData> _loadHeaderData() async {
    final companyName = await _getCompanyName();
    final user = await LocalStorageService.loadLastUsedUser();
    return _HomeHeaderData(companyName: companyName, user: user);
  }

  Future<String?> _getCompanyName() async {
    final id = vm.selectedCompanyId;
    if (id == null) return null;

    final db = DatabaseManager.instance.db;
    final rows = await (db.select(
      db.companyTable,
    )..where((tbl) => tbl.companyId.equals(id))).get();

    return rows.isNotEmpty ? rows.first.companyName : "Your Company";
  }

  String _roleLabel(UserModel? user) {
    final roles =
        user?.roleCodes.map((e) => e.trim().toUpperCase()).toList() ??
        const <String>[];
    if (roles.contains('OWNER')) return 'Owner';
    if (roles.contains('ADMIN')) return 'Administrator';
    if (roles.contains('ACCOUNTANT')) return 'Accountant';
    if (roles.contains('MANAGER')) return 'Manager';
    if (roles.isNotEmpty) {
      final raw = roles.first.toLowerCase();
      return raw[0].toUpperCase() + raw.substring(1);
    }
    return 'Member';
  }
}

class _HomeHeaderData {
  final String? companyName;
  final UserModel? user;

  const _HomeHeaderData({required this.companyName, required this.user});
}

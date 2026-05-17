import 'package:flutter/material.dart';

import '../../../data/local/database_manager.dart';
import '../../../model/user_model.dart';
import '../../../services/local_storage.dart';
import '../../../viewmodel/home/home_view_model.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kHomeBrandBlue, _kHomeBrandBlueDark],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x261862A3),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Color(0xFFE3F0FB),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Mahfooz Accounts MKB',
                          style: TextStyle(
                            color: Color(0xFFD8EAF9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onChangeCompany,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Logged in account',
                              style: TextStyle(
                                color: Color(0xFFD8EAF9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            color: _kHomeBrandBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    final roles = user?.roleCodes.map((e) => e.trim().toUpperCase()).toList() ??
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

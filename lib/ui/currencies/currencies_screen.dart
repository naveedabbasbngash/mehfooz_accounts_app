import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_manager.dart';
import '../commons/currency_flag.dart';

const Color _kCurrenciesBlue = Color(0xFF1862A3);
const Color _kCurrenciesBlueDark = Color(0xFF0F4E88);
const Color _kCurrenciesBg = Color(0xFFF4F8FC);

class CurrenciesScreen extends StatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  State<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends State<CurrenciesScreen> {
  String _searchQuery = "";

  AppDatabase get _db => DatabaseManager.instance.db;

  Stream<List<AccTypeData>> _watchCurrencies() {
    final query = _db.select(_db.accType)
      ..orderBy([
        (t) => OrderingTerm.asc(t.accTypeName),
        (t) => OrderingTerm.asc(t.accTypeId),
      ]);
    return query.watch();
  }

  String _countryNameForCurrency(String currency) =>
      currencyCountryName(currency);

  bool _matchesSearch(AccTypeData row) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    final name = (row.accTypeName ?? "").toLowerCase();
    final country = _countryNameForCurrency(name).toLowerCase();
    final id = row.accTypeId.toString();
    return name.contains(q) || country.contains(q) || id.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCurrenciesBg,
      body: Stack(
        children: [
          const _CurrenciesBackdrop(),
          SafeArea(
            child: StreamBuilder<List<AccTypeData>>(
              stream: _watchCurrencies(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRows = snapshot.data ?? const <AccTypeData>[];
                final rows = allRows.where(_matchesSearch).toList();

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kCurrenciesBlue, _kCurrenciesBlueDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x261862A3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.currency_exchange_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Currencies',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${allRows.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: "Search by currency, country, or ID",
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _kCurrenciesBlue,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE7F8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _kCurrenciesBlue,
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF5FF),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: const Icon(
                                        Icons.currency_exchange_rounded,
                                        size: 34,
                                        color: _kCurrenciesBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _searchQuery.trim().isEmpty
                                          ? "No currencies found."
                                          : "No currencies match your search.",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                              itemCount: rows.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final name = (row.accTypeName ?? "").trim();
                                final countryName = _countryNameForCurrency(name);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFDCE7F8),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x140F172A),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFF8FBFF),
                                        border: Border.all(
                                          color: const Color(0xFFDCE7F8),
                                          width: 1.2,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: ClipOval(
                                        child: CurrencyFlagBadge(
                                          currency: name,
                                          size: 42,
                                          flagField: row.flag,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name.isEmpty ? "Unknown Currency" : name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    subtitle: Text(
                                      countryName,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF5FF),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '#${row.accTypeId}',
                                        style: const TextStyle(
                                          color: _kCurrenciesBlue,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrenciesBackdrop extends StatelessWidget {
  const _CurrenciesBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _kCurrenciesBg),
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x331862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 170,
          left: -80,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x1F1862A3), Color(0x001862A3)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

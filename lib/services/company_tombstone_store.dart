import 'package:shared_preferences/shared_preferences.dart';

class CompanyTombstoneData {
  final Set<int> companyIds;
  final Set<String> companyNames;

  const CompanyTombstoneData({
    required this.companyIds,
    required this.companyNames,
  });
}

class CompanyTombstoneStore {
  static const String _idsKey = 'sync_deleted_company_ids_v1';
  static const String _namesKey = 'sync_deleted_company_names_v1';

  static String normalizeName(String? raw) {
    final cleaned = (raw ?? '').trim().toLowerCase();
    if (cleaned.isEmpty) return '';
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<CompanyTombstoneData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_idsKey) ?? const <String>[])
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toSet();
    final names = (prefs.getStringList(_namesKey) ?? const <String>[])
        .map(normalizeName)
        .where((e) => e.isNotEmpty)
        .toSet();
    return CompanyTombstoneData(companyIds: ids, companyNames: names);
  }

  static Future<void> markDeleted({
    required int companyId,
    String? companyName,
  }) async {
    if (companyId <= 0 && (companyName ?? '').trim().isEmpty) return;

    final data = await load();
    if (companyId > 0) data.companyIds.add(companyId);
    final normalizedName = normalizeName(companyName);
    if (normalizedName.isNotEmpty) data.companyNames.add(normalizedName);

    await _save(data);
  }

  static Future<void> clear({int? companyId, String? companyName}) async {
    final data = await load();
    if ((companyId ?? 0) > 0) {
      data.companyIds.remove(companyId);
    }
    final normalizedName = normalizeName(companyName);
    if (normalizedName.isNotEmpty) {
      data.companyNames.remove(normalizedName);
    }
    await _save(data);
  }

  static bool isBlocked(
    CompanyTombstoneData data, {
    required int companyId,
    String? companyName,
  }) {
    if (companyId > 0 && data.companyIds.contains(companyId)) return true;
    final normalizedName = normalizeName(companyName);
    if (normalizedName.isNotEmpty &&
        data.companyNames.contains(normalizedName)) {
      return true;
    }
    return false;
  }

  static Future<void> _save(CompanyTombstoneData data) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = data.companyIds.map((e) => '$e').toList()..sort();
    final names = data.companyNames.toList()..sort();
    await prefs.setStringList(_idsKey, ids);
    await prefs.setStringList(_namesKey, names);
  }
}

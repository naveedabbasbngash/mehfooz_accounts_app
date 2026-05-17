import 'package:shared_preferences/shared_preferences.dart';

class ReportPreferencesService {
  static const String subgroupFiltersEnabledKey =
      'report_subgroup_filters_enabled';

  static Future<bool> getSubgroupFiltersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(subgroupFiltersEnabledKey) ?? false;
  }

  static Future<void> setSubgroupFiltersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(subgroupFiltersEnabledKey, enabled);
  }
}

class ReportDateHelper {
  static String nowIso() {
    final now = DateTime.now();
    return now.toIso8601String().substring(0, 19).replaceAll('T', ' ');
  }
}
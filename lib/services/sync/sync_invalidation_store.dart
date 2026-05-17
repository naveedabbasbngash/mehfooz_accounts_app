import 'package:shared_preferences/shared_preferences.dart';

class SyncInvalidationHint {
  final bool pending;
  final String? cursor;
  final String? companyId;
  final String? reason;

  const SyncInvalidationHint({
    required this.pending,
    this.cursor,
    this.companyId,
    this.reason,
  });
}

class SyncInvalidationStore {
  static const String _kPending = 'sync_pending_invalidation';
  static const String _kCursor = 'sync_pending_invalidation_cursor';
  static const String _kCompanyId = 'sync_pending_invalidation_company_id';
  static const String _kReason = 'sync_pending_invalidation_reason';
  static const String _kUpdatedAt = 'sync_pending_invalidation_updated_at';

  static bool _isInvalidationPayload(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['event'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return type == 'sync_invalidate' || type == 'sync.invalidate';
  }

  static Future<bool> markFromPayload(
    Map<String, dynamic> data, {
    String source = 'unknown',
  }) async {
    if (!_isInvalidationPayload(data)) return false;
    final cursor = (data['cursor'] ?? '').toString().trim();
    final companyId = (data['company_id'] ?? data['companyId'] ?? '')
        .toString()
        .trim();
    final reason = (data['reason'] ?? source).toString().trim();
    await markPending(cursor: cursor, companyId: companyId, reason: reason);
    return true;
  }

  static Future<void> markPending({
    String? cursor,
    String? companyId,
    String? reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPending, true);

    final cleanCursor = cursor?.trim() ?? '';
    if (cleanCursor.isNotEmpty) {
      await prefs.setString(_kCursor, cleanCursor);
    }

    final cleanCompany = companyId?.trim() ?? '';
    if (cleanCompany.isNotEmpty) {
      await prefs.setString(_kCompanyId, cleanCompany);
    }

    final cleanReason = reason?.trim() ?? '';
    if (cleanReason.isNotEmpty) {
      await prefs.setString(_kReason, cleanReason);
    }

    await prefs.setInt(_kUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<SyncInvalidationHint> peekPending() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_kPending) ?? false;
    if (!pending) {
      return const SyncInvalidationHint(pending: false);
    }

    final cursor = prefs.getString(_kCursor)?.trim();
    final companyId = prefs.getString(_kCompanyId)?.trim();
    final reason = prefs.getString(_kReason)?.trim();
    return SyncInvalidationHint(
      pending: true,
      cursor: (cursor == null || cursor.isEmpty) ? null : cursor,
      companyId: (companyId == null || companyId.isEmpty) ? null : companyId,
      reason: (reason == null || reason.isEmpty) ? null : reason,
    );
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPending);
    await prefs.remove(_kCursor);
    await prefs.remove(_kCompanyId);
    await prefs.remove(_kReason);
    await prefs.remove(_kUpdatedAt);
  }
}


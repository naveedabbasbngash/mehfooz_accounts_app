// lib/services/sync_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Represents one outbound batch for mobile:
/// - batchId: unique per push
/// - checksum: integrity check (SHA-256 from server)
/// - lists of rows to apply locally
class SyncBatch {
  final String batchId;
  final String checksum;

  final List<Map<String, dynamic>> accPersonal;
  final List<Map<String, dynamic>> accTypes;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> transactions;

  SyncBatch({
    required this.batchId,
    required this.checksum,
    required this.accPersonal,
    required this.accTypes,
    required this.assignments,
    required this.transactions,
  });

  bool get isEmpty =>
      accPersonal.isEmpty &&
          accTypes.isEmpty &&
          assignments.isEmpty &&
          transactions.isEmpty;

  @override
  String toString() {
    return 'SyncBatch(batchId=$batchId, checksum=$checksum, '
        'accPersonal=${accPersonal.length}, '
        'accTypes=${accTypes.length}, '
        'assignments=${assignments.length}, '
        'transactions=${transactions.length})';
  }
}

/// Low-level HTTP client for sync API.
/// Does NOT touch Drift or DatabaseManager.
/// Repositories/ViewModels will use this.
class SyncService {
  /// Example: "https://kheloaurjeeto.net/mahfooz_accounts/"
  final String baseUrl;

  final Logger _log;

  SyncService({
    String? baseUrl,
    Logger? logger,
  })  : baseUrl = baseUrl!.trim().endsWith('/')
      ? baseUrl!.trim()
      : (baseUrl ?? 'https://kheloaurjeeto.net/mahfooz_accounts/'),
        _log = logger ?? Logger();

  Uri _buildUri(String path) {
    // Ensure no double slashes
    final normalizedBase =
    baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }

  /// ------------------------------------------------------------
  /// PULL FOR MOBILE
  ///   POST /pull-for-mobile
  ///   BODY: { "email": "<user email>" }
  ///
  /// Returns:
  ///   - null  → if server says "empty"
  ///   - SyncBatch → if there is a batch to apply
  /// Throws:
  ///   - Exception on network / protocol errors
  /// ------------------------------------------------------------
  Future<SyncBatch?> pullForMobile({required String email}) async {
    _log.i('📡 [SyncService] pullForMobile email=$email');

    final uri = _buildUri('pull-for-mobile');

    final payload = <String, dynamic>{
      'email': email,
    };

    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e, st) {
      _log.e('❌ [SyncService] pullForMobile network error', error: e, stackTrace: st);
      throw Exception('Network error while pulling sync batch: $e');
    }

    if (resp.statusCode != 200) {
      _log.e(
          '❌ [SyncService] pullForMobile bad status ${resp.statusCode} body=${resp.body}');
      throw Exception('pull-for-mobile failed with status ${resp.statusCode}');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e, st) {
      _log.e('❌ [SyncService] pullForMobile invalid JSON', error: e, stackTrace: st);
      throw Exception('Invalid JSON from pull-for-mobile: $e');
    }

    final status = (body['status'] ?? '').toString().toLowerCase();
    _log.d('📡 [SyncService] pullForMobile status=$status');

    if (status == 'empty') {
      // No rows to sync for this email
      return null;
    }
    if (status != 'ok') {
      _log.e('❌ [SyncService] pullForMobile unexpected status=$status body=$body');
      throw Exception('pull-for-mobile returned status=$status');
    }

    final batchId = body['batch_id']?.toString() ?? '';
    final checksum = body['checksum']?.toString() ?? '';

    if (batchId.isEmpty) {
      throw Exception('pull-for-mobile: missing batch_id');
    }

    final rows = body['rows'] as Map<String, dynamic>? ?? {};

    List<Map<String, dynamic>> _readList(String key) {
      final raw = rows[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    final accPersonal = _readList('acc_personal');
    final accTypes = _readList('acc_types');
    final assignments = _readList('assignments');
    final transactions = _readList('transactions');

    final batch = SyncBatch(
      batchId: batchId,
      checksum: checksum,
      accPersonal: accPersonal,
      accTypes: accTypes,
      assignments: assignments,
      transactions: transactions,
    );

    _log.i('✅ [SyncService] pullForMobile received $batch');

    return batch;
  }

  /// ------------------------------------------------------------
  /// ACK BATCH
  ///   POST /ack-batch
  ///   BODY: { "email": "...", "batch_id": "...", "status": "OK"|"FAILED" }
  ///
  /// Returns true on success.
  /// ------------------------------------------------------------
  Future<bool> ackBatch({
    required String email,
    required String batchId,
    required bool success,
  }) async {
    final uri = _buildUri('ack-batch');
    final status = success ? 'OK' : 'FAILED';

    _log.i(
        '📡 [SyncService] ackBatch email=$email batchId=$batchId status=$status');

    final payload = <String, dynamic>{
      'email': email,
      'batch_id': batchId,
      'status': status,
    };

    http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e, st) {
      _log.e('❌ [SyncService] ackBatch network error', error: e, stackTrace: st);
      throw Exception('Network error while sending ack-batch: $e');
    }

    if (resp.statusCode != 200) {
      _log.e(
          '❌ [SyncService] ackBatch bad status ${resp.statusCode} body=${resp.body}');
      return false;
    }

    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final respStatus = decoded['status']?.toString().toLowerCase() ?? '';
      if (respStatus != 'ok') {
        _log.w(
            '⚠️ [SyncService] ackBatch server responded with status=$respStatus body=$decoded');
        return false;
      }
    } catch (e, st) {
      _log.e('❌ [SyncService] ackBatch invalid JSON', error: e, stackTrace: st);
      return false;
    }

    _log.i('✅ [SyncService] ackBatch OK for batchId=$batchId');
    return true;
  }
}
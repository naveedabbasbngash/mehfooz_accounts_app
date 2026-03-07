// lib/services/sync_service.dart
import 'dart:async';
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

class PendingBatchItem {
  final String batchId;
  final String status;
  final int entryCount;
  final String? createdAt;
  final String? updatedAt;

  const PendingBatchItem({
    required this.batchId,
    required this.status,
    required this.entryCount,
    this.createdAt,
    this.updatedAt,
  });
}

/// Low-level HTTP client for sync API.
/// Does NOT touch Drift or DatabaseManager.
/// Repositories/ViewModels will use this.
class SyncService {
  /// Example: "https://admin.mahfoozaccounts.com/"
  final String baseUrl;

  final Logger _log;
  static const Duration _pullRequestTimeout = Duration(seconds: 25);
  static const Duration _ackRequestTimeout = Duration(seconds: 15);
  static const Duration _pendingRequestTimeout = Duration(seconds: 12);

  SyncService({String? baseUrl, Logger? logger})
    : baseUrl =
          (baseUrl ?? 'https://admin.mahfoozaccounts.com/').trim().endsWith('/')
          ? (baseUrl ?? 'https://admin.mahfoozaccounts.com/').trim()
          : (baseUrl ?? 'https://admin.mahfoozaccounts.com/').trim(),
      _log = logger ?? Logger();

  Uri _buildUri(String path) {
    // Ensure no double slashes
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }

  /// ------------------------------------------------------------
  /// PULL FOR MOBILE
  ///   POST /pull-for-mobile
  ///   BODY: { "email": "user email", "device_id": "unique device id" }
  ///
  /// Returns:
  ///   - null  → if server says "empty"
  ///   - SyncBatch → if there is a batch to apply
  /// Throws:
  ///   - Exception on network / protocol errors
  /// ------------------------------------------------------------
  Future<SyncBatch?> pullForMobile({
    required String email,
    required String deviceId,
  }) async {
    _log.i('📡 [SyncService] pullForMobile email=$email device_id=$deviceId');

    final uri = _buildUri('pull-for-mobile');

    final payload = <String, dynamic>{'email': email, 'device_id': deviceId};
    _logRequest('POST', uri, payload);

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_pullRequestTimeout);
    } on TimeoutException catch (e, st) {
      _log.e('❌ [SyncService] pullForMobile timeout', error: e, stackTrace: st);
      throw Exception('Timeout while pulling sync batch');
    } catch (e, st) {
      _log.e(
        '❌ [SyncService] pullForMobile network error',
        error: e,
        stackTrace: st,
      );
      throw Exception('Network error while pulling sync batch: $e');
    }

    if (resp.statusCode != 200) {
      _log.e(
        '❌ [SyncService] pullForMobile bad status ${resp.statusCode} body=${resp.body}',
      );
      throw Exception('pull-for-mobile failed with status ${resp.statusCode}');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e, st) {
      _log.e(
        '❌ [SyncService] pullForMobile invalid JSON',
        error: e,
        stackTrace: st,
      );
      throw Exception('Invalid JSON from pull-for-mobile: $e');
    }

    final status = (body['status'] ?? '').toString().toLowerCase();
    _log.d('📡 [SyncService] pullForMobile status=$status');

    // ✅ SAME behavior: empty => null
    if (status == 'empty') {
      // No rows to sync for this email
      return null;
    }

    // ✅ UPDATED: future-proof for permission denied / blocked responses
    // Example server future:
    // { "status": "denied", "message": "Sync not allowed" }
    if (status != 'ok') {
      final msg = (body['message'] ?? 'pull-for-mobile returned status=$status')
          .toString();
      _log.w(
        '⛔ [SyncService] pullForMobile blocked status=$status message=$msg',
      );
      throw Exception(msg);
    }

    final batchId = body['batch_id']?.toString() ?? '';
    final checksum = body['checksum']?.toString() ?? '';

    if (batchId.isEmpty) {
      throw Exception('pull-for-mobile: missing batch_id');
    }

    final rows = body['rows'] as Map<String, dynamic>? ?? {};

    List<Map<String, dynamic>> readList(String key) {
      final raw = rows[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    final accPersonal = readList('acc_personal');
    final accTypes = readList('acc_types');
    final assignments = readList('assignments');
    final transactions = readList('transactions');

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
    required String deviceId,
    required String batchId,
    required bool success,
  }) async {
    final uri = _buildUri('ack-batch');
    final status = success ? 'OK' : 'FAILED';

    _log.i(
      '📡 [SyncService] ackBatch email=$email device_id=$deviceId batchId=$batchId status=$status',
    );

    final payload = <String, dynamic>{
      'email': email,
      'device_id': deviceId,
      'batch_id': batchId,
      'status': status,
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_ackRequestTimeout);
    } on TimeoutException catch (e, st) {
      _log.e('❌ [SyncService] ackBatch timeout', error: e, stackTrace: st);
      throw Exception('Timeout while sending ack-batch');
    } catch (e, st) {
      _log.e(
        '❌ [SyncService] ackBatch network error',
        error: e,
        stackTrace: st,
      );
      throw Exception('Network error while sending ack-batch: $e');
    }

    if (resp.statusCode != 200) {
      _log.e(
        '❌ [SyncService] ackBatch bad status ${resp.statusCode} body=${resp.body}',
      );
      return false;
    }

    try {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final respStatus = decoded['status']?.toString().toLowerCase() ?? '';
      if (respStatus != 'ok') {
        _log.w(
          '⚠️ [SyncService] ackBatch server responded with status=$respStatus body=$decoded',
        );
        return false;
      }
    } catch (e, st) {
      _log.e('❌ [SyncService] ackBatch invalid JSON', error: e, stackTrace: st);
      return false;
    }

    _log.i('✅ [SyncService] ackBatch OK for batchId=$batchId');
    return true;
  }

  /// ------------------------------------------------------------
  /// GET PENDING BATCHES (for current email + device_id)
  ///   POST /get-pending-batches
  ///   BODY: { "email": "...", "device_id": "..." }
  /// ------------------------------------------------------------
  Future<List<PendingBatchItem>> fetchPendingBatches({
    required String email,
    required String deviceId,
  }) async {
    final uri = _buildUri('get-pending-batches');
    final payload = <String, dynamic>{'email': email, 'device_id': deviceId};
    _logRequest('POST', uri, payload);

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_pendingRequestTimeout);
    } on TimeoutException {
      throw Exception('Timeout while loading pending batches');
    } catch (e) {
      throw Exception('Network error while loading pending batches: $e');
    }

    if (resp.statusCode != 200) {
      throw Exception(
        'get-pending-batches failed with status ${resp.statusCode}',
      );
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final status = decoded['status']?.toString().toLowerCase() ?? '';
    if (status != 'ok') {
      final msg =
          decoded['message']?.toString() ?? 'Unable to load pending batches';
      throw Exception(msg);
    }

    final List<PendingBatchItem> result = [];
    final rawRows =
        decoded['rows'] ?? decoded['batches'] ?? decoded['pending_batches'];

    if (rawRows is List) {
      for (final item in rawRows) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final batchId = map['batch_id']?.toString() ?? '';
        if (batchId.isEmpty) continue;
        result.add(
          PendingBatchItem(
            batchId: batchId,
            status: (map['status']?.toString() ?? 'PENDING').toUpperCase(),
            entryCount: _toInt(map['entry_count']),
            createdAt: map['created_at']?.toString(),
            updatedAt: map['updated_at']?.toString(),
          ),
        );
      }
    } else if (decoded['batch_ids'] is String) {
      final ids = (decoded['batch_ids'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final batchId in ids) {
        result.add(
          PendingBatchItem(batchId: batchId, status: 'PENDING', entryCount: 0),
        );
      }
    }

    _log.i(
      '📦 [SyncService] pending batches count=${result.length} for device_id=$deviceId',
    );
    return result;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _logRequest(String method, Uri uri, Map<String, dynamic>? body) {
    _log.i('📡 [HTTP] $method ${uri.toString()}');
    if (body != null) {
      _log.d('📦 [HTTP] body=${jsonEncode(body)}');
    }
  }
}

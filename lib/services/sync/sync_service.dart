// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../utils/ulid.dart';

/// Represents one outbound batch for mobile:
/// - batchId: unique per push
/// - checksum: integrity check (SHA-256 from server)
/// - lists of rows to apply locally
class SyncBatch {
  final String batchId;
  final String checksum;

  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> accountHeads;
  final List<Map<String, dynamic>> accountSubHeads;
  final List<Map<String, dynamic>> chartOfAccounts;
  final List<Map<String, dynamic>> accPersonal;
  final List<Map<String, dynamic>> accTypes;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> transactions;

  SyncBatch({
    required this.batchId,
    required this.checksum,
    required this.companies,
    required this.accountHeads,
    required this.accountSubHeads,
    required this.chartOfAccounts,
    required this.accPersonal,
    required this.accTypes,
    required this.assignments,
    required this.transactions,
  });

  bool get isEmpty =>
      companies.isEmpty &&
      accountHeads.isEmpty &&
      accountSubHeads.isEmpty &&
      chartOfAccounts.isEmpty &&
      accPersonal.isEmpty &&
      accTypes.isEmpty &&
      assignments.isEmpty &&
      transactions.isEmpty;

  @override
  String toString() {
    return 'SyncBatch(batchId=$batchId, checksum=$checksum, '
        'companies=${companies.length}, '
        'accountHeads=${accountHeads.length}, '
        'accountSubHeads=${accountSubHeads.length}, '
        'chartOfAccounts=${chartOfAccounts.length}, '
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

class VerifyDeviceUuidResult {
  final bool isVerified;
  final String message;

  const VerifyDeviceUuidResult({
    required this.isVerified,
    required this.message,
  });
}

class SyncPushResponse {
  final bool ok;
  final int applied;
  final int failed;
  final int? batchId;
  final String message;
  final List<int> failedIndexes;
  final List<String> failedErrors;

  const SyncPushResponse({
    required this.ok,
    required this.applied,
    required this.failed,
    required this.batchId,
    required this.message,
    required this.failedIndexes,
    required this.failedErrors,
  });
}

class RemoteSyncCursorStatus {
  final bool hasUpdates;
  final String? cursor;
  final String source;

  const RemoteSyncCursorStatus({
    required this.hasUpdates,
    required this.cursor,
    required this.source,
  });
}

/// Low-level HTTP client for sync API.
/// Does NOT touch Drift or DatabaseManager.
/// Repositories/ViewModels will use this.
class SyncService {
  /// Example: "https://mkb.mahfoozaccounts.com/"
  final String baseUrl;

  final Logger _log;
  static const Duration _pullRequestTimeout = Duration(seconds: 25);
  static const Duration _ackRequestTimeout = Duration(seconds: 15);
  static const Duration _pendingRequestTimeout = Duration(seconds: 12);
  static const Duration _verifyRequestTimeout = Duration(seconds: 15);
  static const Duration _pushRequestTimeout = Duration(seconds: 25);
  static const String _mkbBaseUrl = 'https://mkb.mahfoozaccounts.com';
  static const String _legacyAdminBaseUrl = 'https://admin.mahfoozaccounts.com';

  static const List<String> _mkbPushEndpoints = [
    'https://mkb.mahfoozaccounts.com/index.php/api/v1/sync/push',
    'https://mkb.mahfoozaccounts.com/api/v1/sync/push',
  ];
  Uri? _preferredVerifyUri;
  Uri? _preferredPullUri;
  Uri? _preferredAckUri;
  Uri? _preferredPendingUri;
  Uri? _preferredCursorUri;

  SyncService({String? baseUrl, Logger? logger})
    : baseUrl = (baseUrl ?? '$_mkbBaseUrl/').trim().endsWith('/')
          ? (baseUrl ?? '$_mkbBaseUrl/').trim()
          : (baseUrl ?? '$_mkbBaseUrl/').trim(),
      _log = logger ?? Logger();

  Uri _buildUri(String path) {
    // Ensure no double slashes
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }

  List<Uri> _uniqueUris(List<String> candidates) {
    final uris = <Uri>[];
    final seen = <String>{};
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        uris.add(Uri.parse(value));
      }
    }
    return uris;
  }

  List<Uri> _orderedWithPreferred(List<Uri> uris, Uri? preferred) {
    if (preferred == null) return uris;
    // Do not pin legacy admin endpoints as preferred forever.
    // Always try MKB routes first, keep legacy as fallback only.
    if (_isLegacyAdminUri(preferred)) {
      return uris;
    }
    final ordered = <Uri>[preferred];
    for (final uri in uris) {
      if (uri.toString() != preferred.toString()) {
        ordered.add(uri);
      }
    }
    return ordered;
  }

  List<Uri> _withoutLegacyAdmin(List<Uri> uris) {
    return uris.where((uri) => !_isLegacyAdminUri(uri)).toList(growable: false);
  }

  String _shortBody(String body, {int max = 220}) {
    final normalized = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= max) return normalized;
    return normalized.substring(0, max);
  }

  bool _isLegacyAdminUri(Uri uri) {
    final legacyHost = Uri.parse(_legacyAdminBaseUrl).host.toLowerCase();
    return uri.host.toLowerCase() == legacyHost;
  }

  Future<VerifyDeviceUuidResult> verifyDeviceUuid({
    required String email,
    required String uuid,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUuid = uuid.trim();

    _log.i(
      '📡 [SyncService] verifyDeviceUuid email=$cleanEmail uuid=$cleanUuid',
    );

    final uris = _orderedWithPreferred(
      _uniqueUris([
        _buildUri('api/verifyDeviceUuid').toString(),
        '$_mkbBaseUrl/index.php/api/verifyDeviceUuid',
        '$_legacyAdminBaseUrl/api/verifyDeviceUuid',
      ]),
      _preferredVerifyUri,
    );

    VerifyDeviceUuidResult? lastFailure;
    for (final uri in uris) {
      http.Response resp;
      try {
        resp = await http
            .post(
              uri,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              body: {'email': cleanEmail, 'uuid': cleanUuid},
            )
            .timeout(_verifyRequestTimeout);
      } on TimeoutException {
        lastFailure = const VerifyDeviceUuidResult(
          isVerified: false,
          message: 'Verification timed out. Please try again.',
        );
        continue;
      } catch (e) {
        lastFailure = VerifyDeviceUuidResult(
          isVerified: false,
          message: 'Network error during verification: $e',
        );
        continue;
      }

      if (resp.statusCode == 404) {
        continue;
      }

      if (resp.statusCode != 200) {
        lastFailure = VerifyDeviceUuidResult(
          isVerified: false,
          message: 'Verification failed (${resp.statusCode}).',
        );
        continue;
      }

      final raw = resp.body.trim();
      if (raw.isEmpty) {
        lastFailure = const VerifyDeviceUuidResult(
          isVerified: false,
          message: 'Invalid server response.',
        );
        continue;
      }

      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map<String, dynamic>) {
          final statusValue = decoded['status'];
          final status = statusValue?.toString().toLowerCase() ?? '';
          final statusBool = statusValue is bool ? statusValue : null;
          final message = (decoded['message'] ?? '').toString();
          final data = decoded['data'];
          final dataMap = data is Map<String, dynamic> ? data : null;
          final isEnabled = dataMap?['is_enabled'];
          final isEnabledBool = isEnabled is bool ? isEnabled : null;
          final verifiedBool =
              decoded['verified'] == true ||
              decoded['success'] == true ||
              decoded['is_verified'] == true;
          final statusOk =
              status == 'ok' || status == 'success' || status == 'verified';
          final statusFalse = statusBool == false || status == 'false';

          if (statusFalse) {
            _preferredVerifyUri = uri;
            return VerifyDeviceUuidResult(
              isVerified: false,
              message: message.isEmpty
                  ? 'Invalid UUID for this email'
                  : message,
            );
          }

          if (isEnabledBool == false) {
            final statusText = (dataMap?['status_text'] ?? '')
                .toString()
                .trim();
            final disabledMessage = statusText.isEmpty
                ? 'UUID found but disabled'
                : 'UUID found but $statusText';
            _preferredVerifyUri = uri;
            return VerifyDeviceUuidResult(
              isVerified: false,
              message: message.isEmpty ? disabledMessage : message,
            );
          }

          if (isEnabledBool == true) {
            _preferredVerifyUri = uri;
            return VerifyDeviceUuidResult(
              isVerified: true,
              message: message.isEmpty ? 'Valid UUID' : message,
            );
          }

          if (verifiedBool || statusOk || statusBool == true) {
            _preferredVerifyUri = uri;
            return VerifyDeviceUuidResult(
              isVerified: true,
              message: message.isEmpty ? 'Reference ID verified' : message,
            );
          }

          lastFailure = VerifyDeviceUuidResult(
            isVerified: false,
            message: message.isEmpty ? 'Reference ID not verified' : message,
          );
          continue;
        }
      } catch (_) {
        // Fallback to non-JSON response check below.
      }

      final lower = raw.toLowerCase();
      if (lower.contains('success') ||
          lower.contains('verified') ||
          lower == 'ok' ||
          lower == 'true' ||
          lower == '1') {
        _preferredVerifyUri = uri;
        return const VerifyDeviceUuidResult(
          isVerified: true,
          message: 'Reference ID verified',
        );
      }

      lastFailure = VerifyDeviceUuidResult(isVerified: false, message: raw);
    }

    return lastFailure ??
        const VerifyDeviceUuidResult(
          isVerified: false,
          message: 'Reference ID verification endpoint not found.',
        );
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
    int? companyId,
    String? companyGuid,
  }) async {
    final cleanCompanyGuid = companyGuid?.trim();
    _log.i(
      '📡 [SyncService] pullForMobile email=$email '
      'device_id=$deviceId company_id=${companyId ?? '(auto)'} '
      'company_guid=${cleanCompanyGuid?.isNotEmpty == true ? cleanCompanyGuid : '(auto)'}',
    );

    final payload = <String, dynamic>{'email': email, 'device_id': deviceId};
    if ((companyId ?? 0) > 0) {
      payload['company_id'] = companyId;
    }
    if (cleanCompanyGuid != null && cleanCompanyGuid.isNotEmpty) {
      payload['company_guid'] = cleanCompanyGuid;
    }
    final uris = _withoutLegacyAdmin(
      _orderedWithPreferred(
        _uniqueUris([
          '$_mkbBaseUrl/index.php/api/v1/sync/pull-for-mobile',
          '$_mkbBaseUrl/index.php/api/v1/sync/pull',
          '$_mkbBaseUrl/api/v1/sync/pull-for-mobile',
          '$_mkbBaseUrl/api/v1/sync/pull',
          _buildUri('api/v1/sync/pull-for-mobile').toString(),
          _buildUri('api/v1/sync/pull').toString(),
          _buildUri('pull-for-mobile').toString(),
        ]),
        _preferredPullUri,
      ),
    );

    Exception? lastError;
    Uri? emptyUri;
    for (final uri in uris) {
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
        _log.e(
          '❌ [SyncService] pullForMobile timeout',
          error: e,
          stackTrace: st,
        );
        lastError = Exception('Timeout while pulling sync batch');
        continue;
      } catch (e, st) {
        _log.e(
          '❌ [SyncService] pullForMobile network error',
          error: e,
          stackTrace: st,
        );
        lastError = Exception('Network error while pulling sync batch: $e');
        continue;
      }

      if (resp.statusCode == 404) {
        continue;
      }

      if (resp.statusCode != 200) {
        lastError = Exception(
          'pull-for-mobile failed with status ${resp.statusCode} '
          '(endpoint=${uri.toString()}, body=${_shortBody(resp.body)})',
        );
        continue;
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
        lastError = Exception(
          'Invalid JSON from pull-for-mobile (endpoint=${uri.toString()}): $e',
        );
        continue;
      }

      final status = (body['status'] ?? '').toString().toLowerCase();
      final statusMessage = (body['message'] ?? '').toString().trim();
      _log.d(
        '📡 [SyncService] pullForMobile status=$status '
        'message=${statusMessage.isEmpty ? '(empty)' : statusMessage} '
        'endpoint=${uri.toString()}',
      );

      if (status == 'empty') {
        if (statusMessage.isNotEmpty) {
          _log.i(
            '📭 [SyncService] pullForMobile empty reason="$statusMessage" endpoint=${uri.toString()}',
          );
        }
        emptyUri ??= uri;
        continue;
      }

      if (status != 'ok') {
        final msg =
            (body['message'] ?? 'pull-for-mobile returned status=$status')
                .toString();
        _log.w(
          '⛔ [SyncService] pullForMobile blocked status=$status message=$msg endpoint=${uri.toString()}',
        );
        lastError = Exception(msg);
        continue;
      }

      final batchId = body['batch_id']?.toString() ?? '';
      final checksum = body['checksum']?.toString() ?? '';

      if (batchId.isEmpty) {
        lastError = Exception('pull-for-mobile: missing batch_id');
        continue;
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

      final companies = readList('companies');
      final accountHeads = readList('account_heads');
      final accountSubHeads = readList('account_sub_heads');
      final chartOfAccounts = readList('chart_of_accounts');
      final accPersonal = readList('acc_personal');
      final accTypes = readList('acc_types');
      final assignments = readList('assignments');
      final transactions = readList('transactions');

      final batch = SyncBatch(
        batchId: batchId,
        checksum: checksum,
        companies: companies,
        accountHeads: accountHeads,
        accountSubHeads: accountSubHeads,
        chartOfAccounts: chartOfAccounts,
        accPersonal: accPersonal,
        accTypes: accTypes,
        assignments: assignments,
        transactions: transactions,
      );

      _log.i(
        '✅ [SyncService] pullForMobile received $batch endpoint=${uri.toString()}',
      );
      _preferredPullUri = uri;
      return batch;
    }

    if (emptyUri != null) {
      _preferredPullUri = emptyUri;
      return null;
    }

    throw lastError ??
        Exception(
          'pull-for-mobile route not found on configured sync backends.',
        );
  }

  Future<SyncPushResponse> pushChangesToMkb({
    required String bearerToken,
    required int tenantId,
    required int companyId,
    required String deviceId,
    required List<Map<String, dynamic>> changes,
    String? companyGuid,
    String? requestId,
  }) async {
    if (changes.isEmpty) {
      return const SyncPushResponse(
        ok: true,
        applied: 0,
        failed: 0,
        batchId: null,
        message: 'No local changes to push',
        failedIndexes: <int>[],
        failedErrors: <String>[],
      );
    }

    final cleanToken = bearerToken.trim();
    if (cleanToken.isEmpty) {
      throw Exception('Missing session token for sync push');
    }

    final payload = <String, dynamic>{
      'tenantId': tenantId,
      'companyId': companyId,
      'deviceId': deviceId,
      'requestId': requestId ?? 'req_${Ulid.generate()}',
      'changes': changes,
    };
    final cleanCompanyGuid = companyGuid?.trim();
    if (cleanCompanyGuid != null && cleanCompanyGuid.isNotEmpty) {
      payload['companyGuid'] = cleanCompanyGuid;
      payload['company_guid'] = cleanCompanyGuid;
    }

    Exception? lastError;
    for (final endpoint in _mkbPushEndpoints) {
      final uri = Uri.parse(endpoint);
      _logRequest('POST', uri, payload);

      http.Response resp;
      try {
        resp = await http
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer $cleanToken',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_pushRequestTimeout);
      } on TimeoutException {
        lastError = Exception('Sync push timed out');
        continue;
      } catch (e) {
        lastError = Exception('Network error while sync push: $e');
        continue;
      }

      if (resp.statusCode == 404) {
        continue;
      }

      Map<String, dynamic>? json;
      if (resp.body.trim().isNotEmpty) {
        try {
          json = jsonDecode(resp.body) as Map<String, dynamic>;
        } catch (_) {
          // ignore malformed JSON and fallback to status handling below
        }
      }

      if (resp.statusCode == 401) {
        throw Exception('Sync push unauthorized. Please sign in again.');
      }
      if (resp.statusCode == 403) {
        final msg = (json?['message'] ?? 'Missing sync.write permission')
            .toString();
        throw Exception(msg);
      }

      if (json != null) {
        final ok = json['status'] == true;
        final msg = (json['message'] ?? '').toString();
        final dataRaw = json['data'];
        final data = dataRaw is Map<String, dynamic>
            ? dataRaw
            : <String, dynamic>{};
        final applied = _toInt(data['applied']);
        final failed = _toInt(data['failed']);
        final batchId = int.tryParse((data['batchId'] ?? '').toString());

        final failedIndexes = <int>[];
        final failedErrors = <String>[];
        final rawErrors = data['errors'];
        if (rawErrors is List) {
          for (final item in rawErrors) {
            if (item is! Map) continue;
            final idx = int.tryParse((item['index'] ?? '').toString());
            if (idx != null && idx >= 0) {
              failedIndexes.add(idx);
            }
            final err = (item['error'] ?? '').toString().trim();
            if (err.isNotEmpty) {
              failedErrors.add(err);
            }
          }
        }

        final resolvedMsg = () {
          if (msg.isNotEmpty) return msg;
          if (failedErrors.isNotEmpty) return failedErrors.first;
          return ok ? 'Push processed' : 'Push failed';
        }();

        _log.i(
          '📥 [HTTP] push response '
          'code=${resp.statusCode} ok=$ok applied=$applied failed=$failed '
          'failedIndexes=${failedIndexes.length} endpoint=$endpoint '
          'msg=${resolvedMsg.isEmpty ? '(empty)' : resolvedMsg}',
        );
        if (failedErrors.isNotEmpty) {
          _log.w(
            '📥 [HTTP] push errors endpoint=$endpoint errors=$failedErrors',
          );
        }

        return SyncPushResponse(
          ok: ok,
          applied: applied,
          failed: failed,
          batchId: batchId,
          message: resolvedMsg,
          failedIndexes: failedIndexes,
          failedErrors: failedErrors,
        );
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _log.i(
          '📥 [HTTP] push response code=${resp.statusCode} '
          'ok=true applied=${changes.length} failed=0 endpoint=$endpoint (non-json)',
        );
        return SyncPushResponse(
          ok: true,
          applied: changes.length,
          failed: 0,
          batchId: null,
          message: 'Push processed',
          failedIndexes: const <int>[],
          failedErrors: const <String>[],
        );
      }

      final bodySnippet = resp.body.trim().isEmpty
          ? ''
          : resp.body
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ')
                .substring(
                  0,
                  resp.body.trim().replaceAll(RegExp(r'\s+'), ' ').length > 220
                      ? 220
                      : resp.body.trim().replaceAll(RegExp(r'\s+'), ' ').length,
                );
      final serverMsg = (json?['message'] ?? '').toString().trim();
      final composed = StringBuffer(
        'Sync push failed (HTTP ${resp.statusCode})',
      );
      if (serverMsg.isNotEmpty) {
        composed.write(' | $serverMsg');
      }
      if (bodySnippet.isNotEmpty) {
        composed.write(' | body=$bodySnippet');
      }
      composed.write(' | endpoint=$endpoint');
      lastError = Exception(composed.toString());
    }

    throw lastError ??
        Exception('Sync push API route not found (404) on MKB server.');
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

    final uris = _withoutLegacyAdmin(
      _orderedWithPreferred(
        _uniqueUris([
          '$_mkbBaseUrl/index.php/api/v1/sync/ack-batch',
          '$_mkbBaseUrl/index.php/api/v1/sync/ack',
          _buildUri('ack-batch').toString(),
        ]),
        _preferredAckUri,
      ),
    );

    Exception? lastError;
    for (final uri in uris) {
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
            .timeout(_ackRequestTimeout);
      } on TimeoutException catch (e, st) {
        _log.e('❌ [SyncService] ackBatch timeout', error: e, stackTrace: st);
        lastError = Exception('Timeout while sending ack-batch');
        continue;
      } catch (e, st) {
        _log.e(
          '❌ [SyncService] ackBatch network error',
          error: e,
          stackTrace: st,
        );
        lastError = Exception('Network error while sending ack-batch: $e');
        continue;
      }

      if (resp.statusCode == 404) {
        continue;
      }
      if (resp.statusCode != 200) {
        lastError = Exception(
          'ack-batch failed with status ${resp.statusCode} '
          '(endpoint=${uri.toString()}, body=${_shortBody(resp.body)})',
        );
        continue;
      }

      try {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final respStatus = decoded['status']?.toString().toLowerCase() ?? '';
        if (respStatus == 'ok') {
          _preferredAckUri = uri;
          _log.i(
            '✅ [SyncService] ackBatch OK for batchId=$batchId endpoint=${uri.toString()}',
          );
          return true;
        }
        lastError = Exception(
          'ack-batch returned status=$respStatus '
          '(endpoint=${uri.toString()}, body=${_shortBody(resp.body)})',
        );
      } catch (e, st) {
        _log.e(
          '❌ [SyncService] ackBatch invalid JSON',
          error: e,
          stackTrace: st,
        );
        lastError = Exception(
          'Invalid JSON from ack-batch (endpoint=${uri.toString()})',
        );
      }
    }

    if (lastError != null) {
      _log.w(
        '⚠️ [SyncService] ackBatch not confirmed: ${lastError.toString()}',
      );
    }
    return false;
  }

  /// Registers (or clears) a device push token for immediate server-triggered
  /// sync invalidation notifications.
  Future<bool> registerDeviceToken({
    required String email,
    required String deviceId,
    required String fcmToken,
    required String platform,
    int? companyId,
    String? bearerToken,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'device_id': deviceId.trim(),
      'fcm_token': fcmToken.trim(),
      'platform': platform.trim().isEmpty ? 'android' : platform.trim(),
    };
    if ((companyId ?? 0) > 0) {
      payload['company_id'] = companyId;
    }

    final uris = _withoutLegacyAdmin(
      _orderedWithPreferred(
        _uniqueUris([
          '$_mkbBaseUrl/index.php/api/v1/sync/register-device-token',
          '$_mkbBaseUrl/api/v1/sync/register-device-token',
          _buildUri('api/v1/sync/register-device-token').toString(),
          _buildUri('sync/register-device-token').toString(),
        ]),
        null,
      ),
    );

    Exception? lastError;
    for (final uri in uris) {
      _logRequest('POST', uri, payload);

      http.Response resp;
      try {
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        final cleanBearer = bearerToken?.trim() ?? '';
        if (cleanBearer.isNotEmpty) {
          headers['Authorization'] = 'Bearer $cleanBearer';
        }

        resp = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(_pendingRequestTimeout);
      } on TimeoutException {
        lastError = Exception('Timeout while registering push token');
        continue;
      } catch (e) {
        lastError = Exception('Network error while registering push token: $e');
        continue;
      }

      if (resp.statusCode == 404) continue;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.trim().isEmpty) return true;
        try {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map<String, dynamic>) {
            final statusRaw = decoded['status'];
            if (statusRaw is bool && statusRaw) return true;
            final status = statusRaw?.toString().toLowerCase() ?? '';
            if (status == 'ok' || status == 'success' || status == 'true') {
              return true;
            }
            final msg = (decoded['message'] ?? '').toString().trim();
            if (msg.isNotEmpty) {
              lastError = Exception(msg);
              continue;
            }
          }
          return true;
        } catch (_) {
          return true;
        }
      }

      lastError = Exception(
        'register-device-token failed with status ${resp.statusCode} '
        '(endpoint=${uri.toString()}, body=${_shortBody(resp.body)})',
      );
    }

    throw lastError ??
        Exception('register-device-token route not found on sync backends');
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
    final payload = <String, dynamic>{'email': email, 'device_id': deviceId};
    final uris = _withoutLegacyAdmin(
      _orderedWithPreferred(
        _uniqueUris([
          '$_mkbBaseUrl/index.php/api/v1/sync/get-pending-batches',
          '$_mkbBaseUrl/index.php/api/v1/sync/pending',
          _buildUri('get-pending-batches').toString(),
        ]),
        _preferredPendingUri,
      ),
    );

    Exception? lastError;
    for (final uri in uris) {
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
        lastError = Exception('Timeout while loading pending batches');
        continue;
      } catch (e) {
        lastError = Exception(
          'Network error while loading pending batches: $e',
        );
        continue;
      }

      if (resp.statusCode == 404) {
        continue;
      }
      if (resp.statusCode != 200) {
        lastError = Exception(
          'get-pending-batches failed with status ${resp.statusCode} '
          '(endpoint=${uri.toString()}, body=${_shortBody(resp.body)})',
        );
        continue;
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = decoded['status']?.toString().toLowerCase() ?? '';
      if (status != 'ok') {
        final msg =
            decoded['message']?.toString() ?? 'Unable to load pending batches';
        lastError = Exception(msg);
        continue;
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
            PendingBatchItem(
              batchId: batchId,
              status: 'PENDING',
              entryCount: 0,
            ),
          );
        }
      }

      _log.i(
        '📦 [SyncService] pending batches count=${result.length} for device_id=$deviceId endpoint=${uri.toString()}',
      );
      _preferredPendingUri = uri;
      return result;
    }

    throw lastError ??
        Exception('get-pending-batches route not found on sync backends');
  }

  /// Lightweight remote invalidation check.
  ///
  /// Tries dedicated cursor/version endpoints first. If unavailable, falls back
  /// to pending-batches as a compatibility path.
  Future<RemoteSyncCursorStatus> peekRemoteCursorStatus({
    required String email,
    required String deviceId,
    String? knownCursor,
    int? companyId,
    String? companyGuid,
  }) async {
    final cleanKnownCursor = knownCursor?.trim();
    final payload = <String, dynamic>{'email': email, 'device_id': deviceId};
    if (cleanKnownCursor != null && cleanKnownCursor.isNotEmpty) {
      payload['cursor'] = cleanKnownCursor;
    }
    if ((companyId ?? 0) > 0) {
      payload['company_id'] = companyId;
    }
    final cleanCompanyGuid = companyGuid?.trim();
    if (cleanCompanyGuid != null && cleanCompanyGuid.isNotEmpty) {
      payload['company_guid'] = cleanCompanyGuid;
    }

    final uris = _withoutLegacyAdmin(
      _orderedWithPreferred(
        _uniqueUris([
          '$_mkbBaseUrl/index.php/api/v1/sync/version',
          '$_mkbBaseUrl/index.php/api/v1/sync/cursor',
          '$_mkbBaseUrl/api/v1/sync/version',
          '$_mkbBaseUrl/api/v1/sync/cursor',
          _buildUri('api/v1/sync/version').toString(),
          _buildUri('api/v1/sync/cursor').toString(),
          _buildUri('sync/version').toString(),
        ]),
        _preferredCursorUri,
      ),
    );

    bool endpointFound = false;
    for (final uri in uris) {
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
        continue;
      } catch (_) {
        continue;
      }

      if (resp.statusCode == 404) continue;
      endpointFound = true;
      if (resp.statusCode != 200) continue;

      Map<String, dynamic> body;
      try {
        body = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      String pickCursor(Map<String, dynamic> map) {
        final candidates = <dynamic>[
          map['cursor'],
          map['version'],
          map['sync_version'],
          map['batch_id'],
          map['batchId'],
          map['checksum'],
        ];
        for (final value in candidates) {
          final s = value?.toString().trim() ?? '';
          if (s.isNotEmpty) return s;
        }
        return '';
      }

      bool? pickBool(Map<String, dynamic> map, List<String> keys) {
        for (final key in keys) {
          final value = map[key];
          if (value is bool) return value;
          if (value is num) return value != 0;
          if (value is String) {
            final raw = value.trim().toLowerCase();
            if (raw == 'true' || raw == '1' || raw == 'yes') return true;
            if (raw == 'false' || raw == '0' || raw == 'no') return false;
          }
        }
        return null;
      }

      final dataRaw = body['data'];
      final data = dataRaw is Map<String, dynamic>
          ? dataRaw
          : <String, dynamic>{};
      final status = (body['status'] ?? '').toString().trim().toLowerCase();
      final cursor = pickCursor(data).isNotEmpty
          ? pickCursor(data)
          : pickCursor(body);
      final hasUpdatesHint =
          pickBool(data, const ['has_updates', 'changed', 'needs_sync']) ??
          pickBool(body, const ['has_updates', 'changed', 'needs_sync']);

      bool hasUpdates;
      if (hasUpdatesHint != null) {
        hasUpdates = hasUpdatesHint;
      } else if (status == 'empty') {
        hasUpdates = false;
      } else if (status == 'ok') {
        if (cursor.isNotEmpty &&
            cleanKnownCursor != null &&
            cleanKnownCursor.isNotEmpty) {
          hasUpdates = cursor != cleanKnownCursor;
        } else {
          hasUpdates = true;
        }
      } else {
        continue;
      }

      _preferredCursorUri = uri;
      return RemoteSyncCursorStatus(
        hasUpdates: hasUpdates,
        cursor: cursor.isEmpty ? null : cursor,
        source: 'cursor-endpoint',
      );
    }

    if (endpointFound) {
      // Endpoint exists but response shape is unknown; fail open to avoid
      // dropping updates.
      return const RemoteSyncCursorStatus(
        hasUpdates: true,
        cursor: null,
        source: 'cursor-endpoint-unknown',
      );
    }

    final pending = await fetchPendingBatches(email: email, deviceId: deviceId);
    if (pending.isEmpty) {
      return RemoteSyncCursorStatus(
        hasUpdates: false,
        cursor: cleanKnownCursor,
        source: 'pending-fallback',
      );
    }

    final remoteCursor = pending.first.batchId.trim();
    final hasUpdates =
        remoteCursor.isNotEmpty &&
        (cleanKnownCursor == null ||
            cleanKnownCursor.isEmpty ||
            remoteCursor != cleanKnownCursor);
    return RemoteSyncCursorStatus(
      hasUpdates: hasUpdates,
      cursor: remoteCursor.isEmpty ? null : remoteCursor,
      source: 'pending-fallback',
    );
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

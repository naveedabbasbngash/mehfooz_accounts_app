import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();
  static const String _exchangeRateApiKey = 'df2e40f00f3e610d2a553a87';

  static const Map<String, String> _aliases = {
    // App-specific / display labels mapped to ISO code.
    'AFG': 'AFN',
    'CANADA DOLLAR': 'CAD',
    'CANADIAN DOLLAR': 'CAD',
    'US DOLLAR': 'USD',
    'U.S. DOLLAR': 'USD',
    'USA DOLLAR': 'USD',
    'DOLLAR': 'USD',
    'EURO': 'EUR',
    'POUND': 'GBP',
    'POUND STERLING': 'GBP',
    'SAUDI RIYAL': 'SAR',
    'UAE DIRHAM': 'AED',
    'DIRHAM': 'AED',
    'PAK RUPEE': 'PKR',
    'PAKISTANI RUPEE': 'PKR',
    'AFGHANI': 'AFN',
  };

  String _norm(String value) => value.trim().toUpperCase();
  String _canon(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');

  String _apiCode(String value) {
    final n = _norm(value);
    if (RegExp(r'^[A-Z]{3}$').hasMatch(n)) {
      return _aliases[n] ?? n;
    }

    final canonical = _canon(value);
    final resolved = _aliases[canonical] ?? n;
    if (resolved != n) {
      _log('alias resolved "$value" -> "$resolved"');
    }
    return resolved;
  }

  void _log(String message) {
    debugPrint('[FxRate] $message');
  }

  Future<Map<String, double>> _fetchViaFrankfurter({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    _log('provider=frankfurter start base=$baseApi targets=${apiTargets.join(',')}');
    final uri = Uri.parse(
      'https://api.frankfurter.app/latest?from=$baseApi&to=${apiTargets.join(',')}',
    );
    final json = await _fetchJson(uri);
    final rates = json['rates'];
    if (rates is! Map) throw Exception('Frankfurter rates missing');

    final out = <String, double>{};
    for (final t in apiTargets) {
      final v = rates[t];
      if (v is num && v > 0) out[t] = v.toDouble();
    }
    _log('provider=frankfurter success mapped=${out.length}');
    return out;
  }

  Future<Map<String, double>> _fetchViaOpenErApi({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    _log('provider=open.er-api start base=$baseApi targets=${apiTargets.join(',')}');
    final uri = Uri.parse('https://open.er-api.com/v6/latest/$baseApi');
    final json = await _fetchJson(uri);
    final result = (json['result'] as String?)?.toLowerCase();
    if (result != 'success') throw Exception('open.er-api result not success');

    final rates = json['rates'];
    if (rates is! Map) throw Exception('open.er-api rates missing');

    final out = <String, double>{};
    for (final t in apiTargets) {
      final v = rates[t];
      if (v is num && v > 0) out[t] = v.toDouble();
    }
    _log('provider=open.er-api success mapped=${out.length}');
    return out;
  }

  Future<Map<String, double>> _fetchViaCurrencyApiCdn({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    _log(
      'provider=currency-api-cdn start base=$baseApi targets=${apiTargets.join(',')}',
    );
    final baseLower = baseApi.toLowerCase();
    final uri = Uri.parse(
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$baseLower.json',
    );
    final json = await _fetchJson(uri);
    final baseObj = json[baseLower];
    if (baseObj is! Map) throw Exception('currency-api-cdn base object missing');

    final out = <String, double>{};
    for (final t in apiTargets) {
      final v = baseObj[t.toLowerCase()];
      if (v is num && v > 0) out[t] = v.toDouble();
    }
    _log('provider=currency-api-cdn success mapped=${out.length}');
    return out;
  }

  Future<Map<String, double>> _fetchViaExchangeRateApi({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    _log('provider=exchangerate-api start base=$baseApi targets=${apiTargets.join(',')}');
    final uri = Uri.parse(
      'https://v6.exchangerate-api.com/v6/$_exchangeRateApiKey/latest/$baseApi',
    );
    final json = await _fetchJson(uri);

    final result = (json['result'] as String?)?.toLowerCase();
    if (result != 'success') {
      throw Exception('exchangerate-api result not success');
    }

    final rates = json['conversion_rates'];
    if (rates is! Map) {
      throw Exception('exchangerate-api conversion_rates missing');
    }

    final out = <String, double>{};
    for (final t in apiTargets) {
      final v = rates[t];
      if (v is num && v > 0) out[t] = v.toDouble();
    }
    _log('provider=exchangerate-api success mapped=${out.length}');
    return out;
  }

  Future<Map<String, double>> _fetchViaFloatRates({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    _log('provider=floatrates start base=$baseApi targets=${apiTargets.join(',')}');
    final uri = Uri.parse(
      'https://www.floatrates.com/daily/${baseApi.toLowerCase()}.json',
    );
    final json = await _fetchJson(uri);

    final out = <String, double>{};
    for (final t in apiTargets) {
      final key = t.toLowerCase();
      final entry = json[key];
      if (entry is Map && entry['rate'] is num) {
        final rate = (entry['rate'] as num).toDouble();
        if (rate > 0) out[t] = rate;
      }
    }
    _log('provider=floatrates success mapped=${out.length}');
    return out;
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      _log('http GET $uri');
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final snippet = body.length > 350 ? '${body.substring(0, 350)}...' : body;
      _log('http ${res.statusCode} $uri');
      _log('body: $snippet');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid JSON payload');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, double>> _fetchRatesWithFallback({
    required String baseApi,
    required List<String> apiTargets,
  }) async {
    final providers = <({
      String name,
      bool paid,
      Future<Map<String, double>> Function(List<String> targets) fetch,
    })>[
      (
        name: 'frankfurter',
        paid: false,
        fetch: (targets) =>
            _fetchViaFrankfurter(baseApi: baseApi, apiTargets: targets),
      ),
      (
        name: 'open.er-api',
        paid: false,
        fetch: (targets) =>
            _fetchViaOpenErApi(baseApi: baseApi, apiTargets: targets),
      ),
      (
        name: 'floatrates',
        paid: false,
        fetch: (targets) =>
            _fetchViaFloatRates(baseApi: baseApi, apiTargets: targets),
      ),
      (
        name: 'currency-api-cdn',
        paid: false,
        fetch: (targets) =>
            _fetchViaCurrencyApiCdn(baseApi: baseApi, apiTargets: targets),
      ),
      // Paid fallback only after all free APIs fail.
      (
        name: 'exchangerate-api',
        paid: true,
        fetch: (targets) =>
            _fetchViaExchangeRateApi(baseApi: baseApi, apiTargets: targets),
      ),
    ];

    final merged = <String, double>{};
    final remaining = apiTargets.toSet();
    var freeUsed = 0;
    var paidUsed = 0;
    Object? lastError;

    for (final provider in providers) {
      if (remaining.isEmpty) break;
      try {
        final requested = remaining.toList(growable: false);
        final rates = await provider.fetch(requested);
        final contributed = <String, double>{};

        for (final key in requested) {
          final v = rates[key];
          if (v != null && v > 0) {
            contributed[key] = v;
          }
        }

        if (contributed.isNotEmpty) {
          merged.addAll(contributed);
          remaining.removeAll(contributed.keys);
          if (provider.paid) {
            paidUsed++;
          } else {
            freeUsed++;
          }
          _log(
            'source tier=${provider.paid ? 'PAID' : 'FREE'} '
            'provider=${provider.name} contributed=${contributed.length} '
            'remaining=${remaining.length}',
          );
          continue;
        }
        _log(
          'source tier=${provider.paid ? 'PAID' : 'FREE'} '
          'provider=${provider.name} returned no usable rates, trying next',
        );
      } catch (e) {
        lastError = e;
        _log(
          'source tier=${provider.paid ? 'PAID' : 'FREE'} '
          'provider=${provider.name} failed: $e',
        );
      }
    }

    _log(
      'summary freeUsed=$freeUsed paidUsed=$paidUsed '
      'covered=${merged.length}/${apiTargets.length}',
    );

    if (remaining.isNotEmpty) {
      _log('missing rates for: ${remaining.join(',')}');
    }

    if (merged.isEmpty) {
      throw Exception('All rate APIs failed: $lastError');
    }
    return merged;
  }

  Future<Map<String, double>> getRates({
    required String baseCurrency,
    required List<String> targetCurrencies,
  }) async {
    final base = _norm(baseCurrency);
    if (base.isEmpty) return const {};
    _log('getRates start base=$base rawTargets=${targetCurrencies.join(',')}');

    final baseApi = _apiCode(base);

    final targets = targetCurrencies
        .map(_norm)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final apiByTarget = <String, String>{};
    for (final t in targets) {
      apiByTarget[t] = _apiCode(t);
    }

    final apiTargets = apiByTarget.values
        .toSet()
        .where((e) => e != baseApi)
        .toList(growable: false);

    final result = <String, double>{base: 1.0};
    _log('normalized base=$baseApi targets=${apiTargets.join(',')}');

    if (apiTargets.isEmpty) {
      for (final t in targets) {
        if (t == base) result[t] = 1.0;
      }
      return result;
    }

    final fetched = await _fetchRatesWithFallback(
      baseApi: baseApi,
      apiTargets: apiTargets,
    );

    for (final entry in apiByTarget.entries) {
      final original = entry.key;
      final api = entry.value;
      if (original == base) {
        result[original] = 1.0;
        continue;
      }
      final val = fetched[api];
      if (val != null && val > 0) {
        result[original] = val;
      }
    }
    _log('getRates done mapped=${result.length} keys=${result.keys.join(',')}');
    return result;
  }
}

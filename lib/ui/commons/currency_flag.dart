import 'package:country_flags/country_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/local/database_manager.dart';

String normalizeCurrency(String value) => value.trim().toUpperCase();

String currencyIsoCode(String currency) {
  switch (normalizeCurrency(currency)) {
    case 'EURO':
      return 'EUR';
    case 'POUND':
      return 'GBP';
    case 'IND':
      return 'INR';
    case 'AFG':
      return 'AFN';
    case 'RMB':
      return 'CNY';
    case 'SGP':
      return 'SGD';
    default:
      return normalizeCurrency(currency);
  }
}

String currencyCountryName(String currency) {
  switch (currencyIsoCode(currency)) {
    case 'PKR':
      return 'Pakistan';
    case 'USD':
      return 'United States';
    case 'AED':
      return 'United Arab Emirates';
    case 'SAR':
      return 'Saudi Arabia';
    case 'EUR':
      return 'European Union';
    case 'GBP':
      return 'United Kingdom';
    case 'INR':
      return 'India';
    case 'AFN':
      return 'Afghanistan';
    case 'CAD':
      return 'Canada';
    case 'JPY':
      return 'Japan';
    case 'CNY':
      return 'China';
    case 'IRR':
      return 'Iran';
    case 'BHD':
      return 'Bahrain';
    case 'OMR':
      return 'Oman';
    case 'QAR':
      return 'Qatar';
    case 'DKK':
      return 'Denmark';
    case 'SEK':
      return 'Sweden';
    case 'NOK':
      return 'Norway';
    case 'MYR':
      return 'Malaysia';
    case 'AUD':
      return 'Australia';
    case 'HKD':
      return 'Hong Kong';
    case 'SGD':
      return 'Singapore';
    case 'RUB':
      return 'Russia';
    default:
      return 'Unknown';
  }
}

class CurrencyFlagBadge extends StatelessWidget {
  final String currency;
  final double size;
  final String? flagField;

  const CurrencyFlagBadge({
    super.key,
    required this.currency,
    this.size = 24,
    this.flagField,
  });

  @override
  Widget build(BuildContext context) {
    final inline = _buildFromFlagPayload(flagField);
    if (inline != null) return inline;

    final cachedRaw = _CurrencyFlagCache.flagForCurrency(currency);
    final cached = _buildFromFlagPayload(cachedRaw);
    if (cached != null) return cached;

    return FutureBuilder<void>(
      future: _CurrencyFlagCache.ensureLoaded(),
      builder: (context, snapshot) {
        final raw = _CurrencyFlagCache.flagForCurrency(currency);
        final fromDb = _buildFromFlagPayload(raw);
        if (fromDb != null) return fromDb;
        return _buildIsoFallback();
      },
    );
  }

  Widget _buildIsoFallback() {
    final iso = currencyIsoCode(currency);
    final flagCode = FlagCode.fromCurrencyCode(iso);

    if (flagCode == null) {
      return _placeholderFlag();
    }

    return SizedBox(
      width: size,
      height: size,
      child: CountryFlag.fromCurrencyCode(
        iso,
        theme: ImageTheme(width: size, height: size, shape: const Circle()),
      ),
    );
  }

  Widget? _buildFromFlagPayload(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;

    final assetPath = _extractAssetPath(rawValue);
    if (assetPath != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => _placeholderFlag(),
          ),
        ),
      );
    }

    final imageUrl = _extractImageUrl(rawValue);
    if (imageUrl != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => _placeholderFlag(),
          ),
        ),
      );
    }

    final emoji = _extractFlagEmoji(rawValue);
    if (emoji == null) return null;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.62)),
    );
  }

  String? _extractAssetPath(String raw) {
    final match = RegExp(
      r'(assets\/[^\s,;]+?\.(png|jpg|jpeg|webp|svg))',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1);
  }

  String? _extractImageUrl(String raw) {
    final match = RegExp(
      r'(https?:\/\/[^\s,;]+?\.(png|jpg|jpeg|webp|svg))',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1);
  }

  String? _extractFlagEmoji(String raw) {
    final buf = StringBuffer();
    for (final rune in raw.runes) {
      final isRegionalIndicator = rune >= 0x1F1E6 && rune <= 0x1F1FF;
      final isLikelyEmojiRune = rune > 0xFFFF;
      if (isRegionalIndicator || isLikelyEmojiRune) {
        buf.writeCharCode(rune);
      }
    }
    final out = buf.toString().trim();
    return out.isEmpty ? null : out;
  }

  Widget _placeholderFlag() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text('🏳️', style: TextStyle(fontSize: size * 0.62)),
    );
  }
}

class _CurrencyFlagCache {
  static Map<String, String>? _byCurrency;
  static Future<void>? _loading;

  static String? flagForCurrency(String currency) {
    final map = _byCurrency;
    if (map == null) return null;
    return map[normalizeCurrency(currency)];
  }

  static Future<void> ensureLoaded() {
    if (_byCurrency != null) {
      return SynchronousFuture(null);
    }

    _loading ??= _loadInternal();
    return _loading!;
  }

  static Future<void> _loadInternal() async {
    try {
      final db = DatabaseManager.instance.db;
      final rows = await db.select(db.accType).get();

      final map = <String, String>{};
      for (final row in rows) {
        final name = (row.accTypeName ?? '').trim();
        final flag = (row.flag ?? '').trim();
        if (name.isEmpty || flag.isEmpty) continue;
        map[normalizeCurrency(name)] = flag;
      }
      _byCurrency = map;
    } catch (_) {
      // DB may not be ready yet on very first frames; fallback renderer will be used.
    } finally {
      _loading = null;
    }
  }
}

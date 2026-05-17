// lib/model/tx_item_ui.dart

class TxItemUi {
  final int voucherNo;
  final String date;
  final String name;
  final String? description;
  final String? quality;
  final double? rate;
  final double? weight;

  /// ✅ REAL values (not cents)
  final double dr;
  final double cr;

  final String? status;
  final String currency;
  final int? userId;
  final String? userEmail;

  TxItemUi({
    required this.voucherNo,
    required this.date,
    required this.name,
    required this.description,
    this.quality,
    this.rate,
    this.weight,
    required this.dr,
    required this.cr,
    required this.status,
    required this.currency,
    this.userId,
    this.userEmail,
  });

  // ------------------------------------------------------------
  // Derived helpers (UI-safe)
  // ------------------------------------------------------------
  bool get isCredit => cr > 0;

  double get amount => isCredit ? cr : dr;

  bool get isZero => amount.abs() < 0.005;

  bool get hasQualitySpecs {
    final hasQuality = (quality ?? '').trim().isNotEmpty;
    return hasQuality || rate != null || weight != null;
  }

  TxItemUi copyWith({String? userEmail}) {
    return TxItemUi(
      voucherNo: voucherNo,
      date: date,
      name: name,
      description: description,
      quality: quality,
      rate: rate,
      weight: weight,
      dr: dr,
      cr: cr,
      status: status,
      currency: currency,
      userId: userId,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  String get descriptionWithSpecs {
    final base = (description ?? '').trim();
    final specs = <String>[];
    final qualityText = quality?.trim();
    if (qualityText != null && qualityText.isNotEmpty) {
      specs.add('Quality: $qualityText');
    }
    if (weight != null) {
      specs.add('Weight: ${_fmtSpec(weight!)}');
    }
    if (rate != null) {
      specs.add('Rate: ${_fmtSpec(rate!)}');
    }

    if (specs.isEmpty) return base;
    if (base.isEmpty) return specs.join(' | ');
    return '$base\n${specs.join(' | ')}';
  }

  static String _fmtSpec(double value) {
    final safe = value.abs() < 0.0000005 ? 0.0 : value;
    final trimmed = safe
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  // ------------------------------------------------------------
  // Row mapper (Drift / SQLite safe)
  // ------------------------------------------------------------
  factory TxItemUi.fromRow(Map<String, Object?> row) {
    double fix(Object? v) {
      if (v == null) return 0.0;
      if (v is num) {
        final d = v.toDouble();
        // 🔒 eliminate -0.0 noise
        return d.abs() < 0.005 ? 0.0 : d;
      }
      return 0.0;
    }

    double? fixNullable(Object? v) {
      if (v == null) return null;
      if (v is num) {
        final d = v.toDouble();
        return d.abs() < 0.0000005 ? 0.0 : d;
      }
      final parsed = double.tryParse(v.toString());
      if (parsed == null) return null;
      return parsed.abs() < 0.0000005 ? 0.0 : parsed;
    }

    int? intOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    String? emailOrNull(Object? v) {
      final text = (v ?? '').toString().trim();
      if (text.isEmpty) return null;
      return text.contains('@') ? text : null;
    }

    return TxItemUi(
      voucherNo: (row['voucherNo'] as int),
      date: (row['date'] as String),
      name: (row['name'] as String?) ?? '',
      description: row['description'] as String?,
      quality: row['quality'] as String?,
      rate: fixNullable(row['rate']),
      weight: fixNullable(row['weight']),
      dr: fix(row['drCents']), // REAL
      cr: fix(row['crCents']), // REAL
      status: row['status'] as String?,
      currency: (row['currency'] as String?) ?? '',
      userId: intOrNull(row['userId'] ?? row['UserID'] ?? row['userid']),
      userEmail: emailOrNull(
        row['userEmail'] ?? row['WName'] ?? row['wName'] ?? row['ownerEmail'],
      ),
    );
  }

  @override
  String toString() {
    return 'TxItemUi(voucherNo=$voucherNo, date=$date, name=$name, '
        'dr=$dr, cr=$cr, currency=$currency, status=$status, '
        'userId=$userId, userEmail=$userEmail)';
  }
}

// lib/model/tx_item_ui.dart

class TxItemUi {
  final int voucherNo;
  final String date;
  final String name;
  final String? description;

  /// ✅ REAL values (not cents)
  final double dr;
  final double cr;

  final String? status;
  final String currency;

  TxItemUi({
    required this.voucherNo,
    required this.date,
    required this.name,
    required this.description,
    required this.dr,
    required this.cr,
    required this.status,
    required this.currency,
  });

  // ------------------------------------------------------------
  // Derived helpers (UI-safe)
  // ------------------------------------------------------------
  bool get isCredit => cr > 0;

  double get amount => isCredit ? cr : dr;

  bool get isZero => amount.abs() < 0.005;

  // ------------------------------------------------------------
  // Row mapper (Drift / SQLite safe)
  // ------------------------------------------------------------
  factory TxItemUi.fromRow(Map<String, Object?> row) {
    double _fix(Object? v) {
      if (v == null) return 0.0;
      if (v is num) {
        final d = v.toDouble();
        // 🔒 eliminate -0.0 noise
        return d.abs() < 0.005 ? 0.0 : d;
      }
      return 0.0;
    }

    return TxItemUi(
      voucherNo: (row['voucherNo'] as int),
      date: (row['date'] as String),
      name: (row['name'] as String?) ?? '',
      description: row['description'] as String?,
      dr: _fix(row['drCents']), // REAL
      cr: _fix(row['crCents']), // REAL
      status: row['status'] as String?,
      currency: (row['currency'] as String?) ?? '',
    );
  }

  @override
  String toString() {
    return 'TxItemUi(voucherNo=$voucherNo, date=$date, name=$name, '
        'dr=$dr, cr=$cr, currency=$currency, status=$status)';
  }
}
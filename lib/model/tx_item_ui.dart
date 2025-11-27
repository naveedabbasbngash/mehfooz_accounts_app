// lib/model/tx_item_ui.dart
class TxItemUi {
  final int voucherNo;
  final String date;
  final String name;
  final String? description;
  final int drCents;
  final int crCents;
  final String? status;
  final String currency;

  bool get isCredit => crCents > 0;
  int get amountCents => isCredit ? crCents : drCents;

  TxItemUi({
    required this.voucherNo,
    required this.date,
    required this.name,
    required this.description,
    required this.drCents,
    required this.crCents,
    required this.status,
    required this.currency,
  });

  /// Map from Drift customSelect row.data (column aliases MUST match)
  factory TxItemUi.fromRow(Map<String, Object?> row) {
    return TxItemUi(
      voucherNo: (row['voucherNo'] as int),
      date: (row['date'] as String),
      name: (row['name'] as String? ?? ''),
      description: row['description'] as String?,
      drCents: (row['drCents'] as int? ?? 0),
      crCents: (row['crCents'] as int? ?? 0),
      status: row['status'] as String?,
      currency: (row['currency'] as String? ?? ''),
    );
  }

  @override
  String toString() {
    return 'TxItemUi(voucherNo=$voucherNo, date=$date, name=$name, '
        'drCents=$drCents, crCents=$crCents, currency=$currency, status=$status)';
  }
}
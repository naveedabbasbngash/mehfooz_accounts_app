// lib/model/pending_row.dart
class PendingRow {
  final int voucherNo;
  final String dateIso;         // "yyyy-MM-dd"
  final String? pd;
  final String? msg;
  final String? sender;
  final String? receiver;
  final String? description;
  final int notPaidAmount;
  final int paidAmount;
  final int balance;
  final String currency;        // e.g. "PKR", "USD"

  PendingRow({
    required this.voucherNo,
    required this.dateIso,
    required this.pd,
    required this.msg,
    required this.sender,
    required this.receiver,
    required this.description,
    required this.notPaidAmount,
    required this.paidAmount,
    required this.balance,
    required this.currency,
  });

  // Map from your SQL SELECT (names match your Kotlin CTE)
  factory PendingRow.fromMap(Map<String, Object?> map) {
    return PendingRow(
      voucherNo     : map['voucherNo'] as int? ?? 0,
      dateIso       : map['beginDate'] as String? ?? '',
      pd            : map['pd'] as String?,
      msg           : map['msgno'] as String?,
      sender        : map['sender'] as String?,
      receiver      : map['receiver'] as String?,
      description   : map['description'] as String?,
      notPaidAmount : map['notPaidAmount'] as int? ?? 0,
      paidAmount    : map['paidAmount'] as int? ?? 0,
      balance       : map['balance'] as int? ?? 0,
      currency      : (map['accTypeName'] as String? ?? '').trim().isEmpty
          ? 'Unknown'
          : (map['accTypeName'] as String),
    );
  }
}
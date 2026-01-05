// lib/model/pending_row.dart

class PendingRow {
  final int voucherNo;
  final String dateIso;         // "yyyy-MM-dd"
  final String? pd;
  final String? msg;
  final String? sender;
  final String? receiver;
  final String? description;

  // 💰 MONEY MUST BE double
  final double notPaidAmount;
  final double paidAmount;
  final double balance;

  final String currency;        // e.g. "PKR", "USD"

  const PendingRow({
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

  /// Map from SQL / Drift row
  /// SAFE for int, double, REAL, NUMERIC
  factory PendingRow.fromMap(Map<String, Object?> map) {
    return PendingRow(
      voucherNo: (map['voucherNo'] as num?)?.toInt() ?? 0,
      dateIso: map['beginDate']?.toString() ?? '',

      pd: map['pd']?.toString(),
      msg: map['msgno']?.toString(),
      sender: map['sender']?.toString(),
      receiver: map['receiver']?.toString(),
      description: map['description']?.toString(),

      // ✅ num → double (handles int + double safely)
      notPaidAmount: (map['notPaidAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,

      currency: (map['accTypeName'] as String?)?.trim().isNotEmpty == true
          ? map['accTypeName'] as String
          : 'Unknown',
    );
  }
}
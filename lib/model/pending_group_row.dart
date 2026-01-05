class PendingGroupRow {
  final int voucherNo;
  final String beginDate;
  final String? msgNo;

  // 💰 MONEY (always double)
  final double notPaidAmount;
  final double paidAmount;
  final double balance;

  final String? sender;
  final String? receiver;
  final int accTypeId;
  final int accId;
  final String? name;
  final String? accTypeName;
  final String? pd;

  const PendingGroupRow({
    required this.voucherNo,
    required this.beginDate,
    required this.msgNo,
    required this.notPaidAmount,
    required this.paidAmount,
    required this.balance,
    required this.sender,
    required this.receiver,
    required this.accTypeId,
    required this.accId,
    required this.name,
    required this.accTypeName,
    required this.pd,
  });

  /// ------------------------------------------------------------
  /// Factory: SAFE parsing from SQLite / Drift customSelect
  /// ------------------------------------------------------------
  factory PendingGroupRow.fromRow(Map<String, dynamic> row) {
    double _toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : 0.0;

    int _toInt(dynamic v) =>
        (v is num) ? v.toInt() : 0;

    String _toStr(dynamic v) =>
        v?.toString() ?? "";

    return PendingGroupRow(
      voucherNo: _toInt(row['voucherNo']),
      beginDate: _toStr(row['beginDate']),
      msgNo: row['msgno']?.toString(),

      // ✅ MONEY — SAFE & CORRECT
      notPaidAmount: _toDouble(row['notPaidAmount']),
      paidAmount: _toDouble(row['paidAmount']),
      balance: _toDouble(row['balance']),

      sender: row['sender']?.toString(),
      receiver: row['receiver']?.toString(),
      accTypeId: _toInt(row['accTypeId']),
      accId: _toInt(row['accId']),
      name: row['name']?.toString(),
      accTypeName: row['accTypeName']?.toString(),
      pd: row['pd']?.toString(),
    );
  }
}
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
    double toDouble(dynamic v) =>
        (v is num) ? v.toDouble() : 0.0;

    int toInt(dynamic v) =>
        (v is num) ? v.toInt() : 0;

    String toStr(dynamic v) =>
        v?.toString() ?? "";

    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (row.containsKey(k) && row[k] != null) return row[k];
      }
      return null;
    }

    return PendingGroupRow(
      voucherNo: toInt(pick(['voucherNo', 'FirstVoucherNo'])),
      beginDate: toStr(pick(['beginDate', 'FirstTDate', 'TDate'])),
      msgNo: pick(['msgno'])?.toString(),

      // ✅ MONEY — SAFE & CORRECT
      notPaidAmount: toDouble(
        pick(['notPaidAmount', 'TotalCredit', 'Credit']),
      ),
      paidAmount: toDouble(
        pick(['paidAmount', 'TotalDebit', 'Debit']),
      ),
      balance: toDouble(
        pick(['balance', 'NetBalance', 'Balance']),
      ),

      sender: pick(['sender', 'Sender'])?.toString(),
      receiver: pick(['receiver', 'Receiver'])?.toString(),
      accTypeId: toInt(pick(['accTypeId', 'AccTypeID'])),
      accId: toInt(pick(['accId', 'AccID'])),
      name: pick(['name', 'Name', 'AccountName'])?.toString(),
      accTypeName: pick(['accTypeName', 'AccTypeName', 'Currency'])?.toString(),
      pd: pick(['pd', 'PD'])?.toString(),
    );
  }
}

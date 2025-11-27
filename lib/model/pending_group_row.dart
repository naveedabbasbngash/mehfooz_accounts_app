class PendingGroupRow {
  final int voucherNo;
  final String beginDate;
  final String? msgNo;
  final int notPaidAmount;
  final int paidAmount;
  final int balance;
  final String? sender;
  final String? receiver;
  final int accTypeId;
  final int accId;
  final String? name;
  final String? accTypeName;
  final String? pd;

  PendingGroupRow({
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

  // Factory constructor for Drift row reading
  factory PendingGroupRow.fromRow(Map<String, dynamic> row) {
    return PendingGroupRow(
      voucherNo: row['voucherNo'] ?? 0,
      beginDate: row['beginDate'] ?? "",
      msgNo: row['msgno'],
      notPaidAmount: row['notPaidAmount'] ?? 0,
      paidAmount: row['paidAmount'] ?? 0,
      balance: row['balance'] ?? 0,
      sender: row['sender'],
      receiver: row['receiver'],
      accTypeId: row['accTypeId'] ?? 0,
      accId: row['accId'] ?? 0,
      name: row['name'],
      accTypeName: row['accTypeName'],
      pd: row['pd'],
    );
  }
}
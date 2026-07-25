class PendingStatusSummary {
  final double allAmount;
  final double paidAmount;
  final double notPaidAmount;

  final int allCount;
  final int paidCount;
  final int notPaidCount;

  const PendingStatusSummary({
    required this.allAmount,
    required this.paidAmount,
    required this.notPaidAmount,
    required this.allCount,
    required this.paidCount,
    required this.notPaidCount,
  });

  static const empty = PendingStatusSummary(
    allAmount: 0,
    paidAmount: 0,
    notPaidAmount: 0,
    allCount: 0,
    paidCount: 0,
    notPaidCount: 0,
  );
}

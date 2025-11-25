class PendingAmountRow {
  final String currency;
  final double totalCr;
  final double totalDr;
  final double balance;

  PendingAmountRow({
    required this.currency,
    required this.totalCr,
    required this.totalDr,
    required this.balance,
  });
}
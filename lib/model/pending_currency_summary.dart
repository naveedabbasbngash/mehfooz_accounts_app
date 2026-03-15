class PendingCurrencySummary {
  final String currency;
  final double notPaidAmount;
  final double paidAmount;

  const PendingCurrencySummary({
    required this.currency,
    required this.notPaidAmount,
    required this.paidAmount,
  });
}

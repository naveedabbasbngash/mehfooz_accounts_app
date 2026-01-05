class BalanceCurrencyUi {
  final String currency;
  final double credit;
  final double debit;

  const BalanceCurrencyUi({
    required this.currency,
    required this.credit,
    required this.debit,
  });

  double get balance => credit - debit;
}
class BalanceCurrencyUi {
  final String currency;
  final int creditCents;
  final int debitCents;

  const BalanceCurrencyUi({
    required this.currency,
    required this.creditCents,
    required this.debitCents,
  });

  int get balanceCents => creditCents - debitCents;
}
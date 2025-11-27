class SimpleCurrencySummary {
  final String currency;
  final int dr;
  final int cr;
  final int balance;

  const SimpleCurrencySummary({
    required this.currency,
    required this.dr,
    required this.cr,
    required this.balance,
  });

  factory SimpleCurrencySummary.fromRow(Map<String, Object?> row) {
    return SimpleCurrencySummary(
      currency: (row['currency'] as String?) ?? '',
      dr: (row['dr'] as int?) ?? 0,
      cr: (row['cr'] as int?) ?? 0,
      balance: (row['balance'] as int?) ?? 0,
    );
  }
}
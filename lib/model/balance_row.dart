class BalanceRow {
  final String name;
  final Map<String, int> byCurrency; // currency -> value in minor units

  BalanceRow({
    required this.name,
    required this.byCurrency,
  });
}
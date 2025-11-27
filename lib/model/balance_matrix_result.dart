import 'balance_row.dart';

class BalanceMatrixResult {
  final List<String> currencies;
  final List<BalanceRow> rows;

  BalanceMatrixResult({
    required this.currencies,
    required this.rows,
  });
}
import 'package:equatable/equatable.dart';

/// Flutter version of Kotlin `LedgerTxn`
/// ✅ Uses REAL money (double), not cents
class LedgerTxn extends Equatable {
  final String voucherNo;
  final DateTime tDate;
  final String description;

  /// Debit amount (REAL)
  final double dr;

  /// Credit amount (REAL)
  final double cr;

  const LedgerTxn({
    required this.voucherNo,
    required this.tDate,
    required this.description,
    required this.dr,
    required this.cr,
  });

  /// Net effect for this row (Cr - Dr)
  double get net => cr - dr;

  /// Hide -0.00 noise
  double _clean(double v) => v.abs() < 0.005 ? 0.0 : v;

  double get cleanDr => _clean(dr);
  double get cleanCr => _clean(cr);
  double get cleanNet => _clean(net);

  @override
  List<Object?> get props => [
    voucherNo,
    tDate,
    description,
    cleanDr,
    cleanCr,
  ];
}

/// Bundle returned from repository
/// ✅ Opening balance is REAL money
class LedgerResult {
  /// Opening balance = SUM(Cr) - SUM(Dr) before fromDate
  final double openingBalance;

  final List<LedgerTxn> rows;

  const LedgerResult({
    required this.openingBalance,
    required this.rows,
  });

  /// Running balance after each transaction
  /// Formula: previous + Cr - Dr
  List<double> get runningBalances {
    double current = openingBalance;
    final balances = <double>[];

    for (final r in rows) {
      current += r.cr.toDouble() - r.dr.toDouble();

      // 🔒 eliminate -0.00 noise
      balances.add(current.abs() < 0.005 ? 0.0 : current);
    }

    return balances;
  }
}
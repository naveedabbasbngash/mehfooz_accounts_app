
import 'package:equatable/equatable.dart';

/// Flutter version of Kotlin `LedgerTxn`
class LedgerTxn extends Equatable {
  final String voucherNo;
  final DateTime tDate;
  final String description;
  final int dr;
  final int cr;

  const LedgerTxn({
    required this.voucherNo,
    required this.tDate,
    required this.description,
    required this.dr,
    required this.cr,
  });

  @override
  List<Object?> get props => [voucherNo, tDate, description, dr, cr];
}

/// Bundle returned from repository
class LedgerResult {
  final int openingBalanceCents; // Cr - Dr before start date
  final List<LedgerTxn> rows;

  LedgerResult({
    required this.openingBalanceCents,
    required this.rows,
  });
}
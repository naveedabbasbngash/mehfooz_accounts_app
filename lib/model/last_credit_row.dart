import 'package:equatable/equatable.dart';

class LastCreditRow extends Equatable {
  final String currencyName;
  final int accId;
  final String customer;
  final String? address;

  final int companyId;   // keep for future (0 for now, like Kotlin)
  final int currencyId;

  /// MONEY FIELDS — MUST BE double (SQLite REAL)
  final double netBalance;
  final double lastCreditAmount;

  final String? lastTransactionDate;
  final int daysSinceLastCredit;

  const LastCreditRow({
    required this.currencyName,
    required this.accId,
    required this.customer,
    this.address,
    required this.companyId,
    required this.currencyId,
    required this.netBalance,
    this.lastTransactionDate,
    required this.daysSinceLastCredit,
    required this.lastCreditAmount,
  });

  factory LastCreditRow.fromRow(Map<String, Object?> row) {
    return LastCreditRow(
      currencyName: (row['CurrencyName'] as String?) ?? '',
      accId: (row['AccID'] as int?) ?? 0,
      customer: (row['Customer'] as String?) ?? '',
      address: row['Address'] as String?,

      companyId: 0, // exactly like your Kotlin placeholder
      currencyId: (row['CurrencyID'] as int?) ?? 0,

      // ✅ SAFE numeric mapping (NO crashes)
      netBalance: (row['NetBalance'] as num?)?.toDouble() ?? 0.0,
      lastCreditAmount:
      (row['LastCreditAmount'] as num?)?.toDouble() ?? 0.0,

      lastTransactionDate: row['LastTransactionDate'] as String?,
      daysSinceLastCredit:
      (row['DaysSinceLastCredit'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    currencyName,
    accId,
    customer,
    address,
    companyId,
    currencyId,
    netBalance,
    lastTransactionDate,
    daysSinceLastCredit,
    lastCreditAmount,
  ];
}
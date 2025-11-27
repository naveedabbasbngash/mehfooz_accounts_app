// lib/model/tx_filter.dart

enum TxFilter {
  all,
  debit,
  credit,
  dateRange,
  balance,
}

extension TxFilterSql on TxFilter {
  String get asOnlyParam {
    switch (this) {
      case TxFilter.all:
        return 'ALL';
      case TxFilter.debit:
        return 'DEBIT';
      case TxFilter.credit:
        return 'CREDIT';
      case TxFilter.dateRange:
        return 'ALL'; // Date filter will use WHERE clause
      case TxFilter.balance:
        return 'ALL'; // same, handled separately
    }
  }
}
class AccountHeadOption {
  /// Compatibility name: this now stores ChartOfAccountID.
  final int accHeadId;

  /// Compatibility name: this now stores ChartOfAccountName.
  final String accHeadName;
  final int? accountHeadId;
  final String? accountHeadName;
  final int? accountSubHeadId;
  final String? accountSubHeadCode;
  final String? accountSubHeadName;
  final String? chartCode;

  const AccountHeadOption({
    required this.accHeadId,
    required this.accHeadName,
    this.accountHeadId,
    this.accountHeadName,
    this.accountSubHeadId,
    this.accountSubHeadCode,
    this.accountSubHeadName,
    this.chartCode,
  });
}

class AccountHeadListRow {
  final int accountHeadId;
  final String accountHeadName;
  final String normalBalance;

  const AccountHeadListRow({
    required this.accountHeadId,
    required this.accountHeadName,
    required this.normalBalance,
  });
}

class AccountSubHeadListRow {
  final int accountSubHeadId;
  final int accountHeadId;
  final String code;
  final String accountSubHeadName;
  final String accountHeadName;

  const AccountSubHeadListRow({
    required this.accountSubHeadId,
    required this.accountHeadId,
    required this.code,
    required this.accountSubHeadName,
    required this.accountHeadName,
  });
}

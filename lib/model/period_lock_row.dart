class PeriodLockRow {
  final int periodLockId;
  final int companyId;
  final String startDate;
  final String endDate;
  final String lockMode;
  final String reason;
  final bool isActive;
  final String createdAt;
  final int? createdByUserId;
  final String? createdByEmail;

  const PeriodLockRow({
    required this.periodLockId,
    required this.companyId,
    required this.startDate,
    required this.endDate,
    required this.lockMode,
    required this.reason,
    required this.isActive,
    required this.createdAt,
    required this.createdByUserId,
    required this.createdByEmail,
  });
}

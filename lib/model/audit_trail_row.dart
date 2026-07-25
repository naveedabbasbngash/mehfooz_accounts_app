class AuditTrailRow {
  final int auditId;
  final int? companyId;
  final String entityType;
  final String entityId;
  final String action;
  final String message;
  final String payload;
  final int? actorUserId;
  final String? actorEmail;
  final String createdAt;

  const AuditTrailRow({
    required this.auditId,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.message,
    required this.payload,
    required this.actorUserId,
    required this.actorEmail,
    required this.createdAt,
  });
}

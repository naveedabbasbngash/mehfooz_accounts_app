class SyncResult {
  final int inserted;
  final int updated;
  final int deleted;

  const SyncResult({
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
  });

  int get total => inserted + updated + deleted;

  bool get hasChanges => total > 0;

  String get label {
    if (!hasChanges) return "No changes";
    if (deleted == 0 && updated == 0) return "+$inserted added";
    if (deleted == 0) return "+$inserted added, $updated updated";
    return "+$inserted added, $updated updated, $deleted removed";
  }
}
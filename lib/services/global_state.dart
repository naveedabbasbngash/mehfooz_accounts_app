// lib/services/global_state.dart

class GlobalState {
  GlobalState._(); // private constructor
  static final GlobalState instance = GlobalState._();

  // =============================
  // Company Selection (SESSION SCOPED)
  // =============================
  int? _selectedCompanyId;
  String? _selectedCompanyName;

  // -----------------------------
  // Safe getters (always valid)
  // -----------------------------
  int get companyId => _selectedCompanyId ?? 1;
  String get companyName => _selectedCompanyName ?? "Your Company";

  // -----------------------------
  // Set active company
  // -----------------------------
  void setCompany({
    required int id,
    required String name,
  }) {
    _selectedCompanyId = id;
    _selectedCompanyName = name;
  }

  // -----------------------------
  // 🔥 HARD RESET (logout / user switch / app restart)
  // -----------------------------
  void reset() {
    _selectedCompanyId = null;
    _selectedCompanyName = null;
  }

  // -----------------------------
  // Debug helper (optional)
  // -----------------------------
  @override
  String toString() {
    return "GlobalState(companyId: $companyId, companyName: $companyName)";
  }
}
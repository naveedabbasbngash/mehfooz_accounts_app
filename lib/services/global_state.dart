// lib/services/global_state.dart

class GlobalState {
  GlobalState._(); // private constructor
  static final GlobalState instance = GlobalState._();

  // =============================
  // Company Selection Global Data
  // =============================
  int? selectedCompanyId;
  String? selectedCompanyName;

  // Convenience getters
  int get companyId => selectedCompanyId ?? 1;
  String get companyName => selectedCompanyName ?? "Your Company";

  // Setters
  void setCompany({
    required int id,
    required String name,
  }) {
    selectedCompanyId = id;
    selectedCompanyName = name;
  }
}
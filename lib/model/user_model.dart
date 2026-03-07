// ✅ UserModel that works with both API & Local Storage
import 'dart:convert';

class UserModel {
  final bool status;
  final String message;

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String imageUrl;
  final int isLogin;

  final PlanStatus? planStatus;
  final ExpiryInfo? expiry;
  final SubscriptionInfo? subscription;

  bool get isValidLoggedInUser => isLogin == 1 && email.isNotEmpty;

  UserModel({
    required this.status,
    required this.message,
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.imageUrl,
    required this.isLogin,
    this.planStatus,
    this.expiry,
    this.subscription,
  });

  /// ============================================================
  /// API RESPONSE PARSER
  /// ============================================================
  factory UserModel.fromApiResponse(Map<String, dynamic> json) {
    final bool apiStatus = json["status"] == true;
    final String apiMessage = json["message"]?.toString() ?? "";

    if (!apiStatus || json["data"] == null) {
      return UserModel.empty(message: apiMessage);
    }

    final data = json["data"];

    return UserModel(
      status: apiStatus,
      message: apiMessage,
      id: data["id"]?.toString() ?? "",
      email: data["email"] ?? "",
      firstName: data["first_name"] ?? "",
      lastName: data["last_name"] ?? "",
      fullName: data["full_name"] ??
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
      imageUrl: data["image_url"] ?? "",
      isLogin: data["is_login"] is int
          ? data["is_login"]
          : int.tryParse(data["is_login"]?.toString() ?? "0") ?? 0,
      planStatus: data["plan_status"] != null
          ? PlanStatus.fromJson(data["plan_status"])
          : null,
      expiry: data["expiry"] != null
          ? ExpiryInfo.fromJson(data["expiry"])
          : null,
      subscription: data["subscription"] != null
          ? SubscriptionInfo.fromJson(data["subscription"])
          : null,
    );
  }

  /// ============================================================
  /// LOCAL STORAGE PARSER
  /// ============================================================
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final data = json["data"] ?? json;

    return UserModel(
      status: json["status"] == true,
      message: json["message"] ?? "",
      id: data["id"]?.toString() ?? "",
      email: data["email"] ?? "",
      firstName: data["first_name"] ?? "",
      lastName: data["last_name"] ?? "",
      fullName: data["full_name"] ??
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
      imageUrl: data["image_url"] ?? "",
      isLogin: data["is_login"] is int
          ? data["is_login"]
          : int.tryParse(data["is_login"]?.toString() ?? "0") ?? 0,
      planStatus: data["plan_status"] != null
          ? PlanStatus.fromJson(data["plan_status"])
          : null,
      expiry: data["expiry"] != null
          ? ExpiryInfo.fromJson(data["expiry"])
          : null,
      subscription: data["subscription"] != null
          ? SubscriptionInfo.fromJson(data["subscription"])
          : null,
    );
  }

  factory UserModel.empty({String message = ""}) {
    return UserModel(
      status: false,
      message: message,
      id: "",
      email: "",
      firstName: "",
      lastName: "",
      fullName: "",
      imageUrl: "",
      isLogin: 0,
      planStatus: null,
      expiry: null,
      subscription: null,
    );
  }

  /// ============================================================
  /// STORAGE SERIALIZER
  /// ============================================================
  Map<String, dynamic> toJson() => {
    "status": status,
    "message": message,
    "id": id,
    "email": email,
    "first_name": firstName,
    "last_name": lastName,
    "full_name": fullName,
    "image_url": imageUrl,
    "is_login": isLogin,
    "plan_status": planStatus?.toJson(),
    "expiry": expiry?.toJson(),
    "subscription": subscription?.toJson(),
  };

  /// ============================================================
  /// DEBUG
  /// ============================================================
  @override
  String toString() => '''
🧍‍♂️ UserModel:
- fullName   : $fullName
- email      : $email
- isLogin    : $isLogin
- plan       : ${planStatus?.statusText ?? 'N/A'}
- canSync    : ${planStatus?.canSync ?? 'N/A'}
- expiry     : ${expiry?.remainingDays ?? 'N/A'} days
''';
}

/// ============================================================
/// PLAN STATUS (UPDATED WITH canSync)
/// ============================================================
class PlanStatus {
  final String statusCode;
  final String statusText;

  /// 🔑 ADMIN-CONTROLLED PERMISSION
  final bool canSync;

  PlanStatus({
    required this.statusCode,
    required this.statusText,
    required this.canSync,
  });

  factory PlanStatus.fromJson(Map<String, dynamic> json) {
    return PlanStatus(
      statusCode: json["status_code"]?.toString() ?? "",
      statusText: json["status_text"]?.toString() ?? "",

      // ========================================================
      // 🔥 BACKWARD SAFE LOGIC
      // If backend does NOT send canSync → ALLOW SYNC
      // ========================================================
      canSync: json.containsKey("canSync")
          ? json["canSync"].toString() == "1"
          : true,

      // 👉 TEMP OVERRIDE (uncomment if needed)
      // canSync: true,
    );
  }

  Map<String, dynamic> toJson() => {
    "status_code": statusCode,
    "status_text": statusText,
    "canSync": canSync ? "1" : "0",
  };
}

/// ============================================================
/// EXPIRY
/// ============================================================
class ExpiryInfo {
  final bool isExpired;
  final int remainingDays;
  final String message;

  ExpiryInfo({
    required this.isExpired,
    required this.remainingDays,
    required this.message,
  });

  factory ExpiryInfo.fromJson(Map<String, dynamic> json) => ExpiryInfo(
    isExpired: json["is_expired"] ?? false,
    remainingDays: json["remaining_days"] ?? 0,
    message: json["message"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "is_expired": isExpired,
    "remaining_days": remainingDays,
    "message": message,
  };
}

/// ============================================================
/// SUBSCRIPTION
/// ============================================================
class SubscriptionInfo {
  final String planTitle;
  final String planDescription;
  final String planPrice;
  final String durationMonths;
  final String startDate;
  final String endDate;

  SubscriptionInfo({
    required this.planTitle,
    required this.planDescription,
    required this.planPrice,
    required this.durationMonths,
    required this.startDate,
    required this.endDate,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionInfo(
        planTitle: json["plan_title"] ?? "",
        planDescription: json["plan_description"] ?? "",
        planPrice: json["plan_price"] ?? "",
        durationMonths: json["duration_months"]?.toString() ?? "",
        startDate: json["start_date"] ?? "",
        endDate: json["end_date"] ?? "",
      );

  Map<String, dynamic> toJson() => {
    "plan_title": planTitle,
    "plan_description": planDescription,
    "plan_price": planPrice,
    "duration_months": durationMonths,
    "start_date": startDate,
    "end_date": endDate,
  };


}
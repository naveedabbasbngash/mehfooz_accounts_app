// ✅ UserModel that works with both API & Local Storage

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
  final List<String> roleCodes;
  final List<String> permissions;

  final PlanStatus? planStatus;
  final ExpiryInfo? expiry;
  final SubscriptionInfo? subscription;

  bool get isValidLoggedInUser => isLogin == 1 && email.isNotEmpty;
  bool get isAdminOrOwner =>
      roleCodes.any((code) => code == 'ADMIN' || code == 'OWNER');

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
    this.roleCodes = const [],
    this.permissions = const [],
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
      fullName:
          data["full_name"] ??
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
      imageUrl: data["image_url"] ?? "",
      isLogin: data["is_login"] is int
          ? data["is_login"]
          : int.tryParse(data["is_login"]?.toString() ?? "0") ?? 0,
      roleCodes: _extractRoleCodes(data),
      permissions: _extractStringList(data["permissions"]),
      planStatus: _mapOrNull(data["plan_status"] ?? data["PlanStatus"]) != null
          ? PlanStatus.fromJson(
              _mapOrNull(data["plan_status"] ?? data["PlanStatus"])!,
            )
          : null,
      expiry: _mapOrNull(data["expiry"] ?? data["Expiry"]) != null
          ? ExpiryInfo.fromJson(_mapOrNull(data["expiry"] ?? data["Expiry"])!)
          : null,
      subscription:
          _mapOrNull(data["subscription"] ?? data["Subscription"]) != null
          ? SubscriptionInfo.fromJson(
              _mapOrNull(data["subscription"] ?? data["Subscription"])!,
            )
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
      fullName:
          data["full_name"] ??
          "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim(),
      imageUrl: data["image_url"] ?? "",
      isLogin: data["is_login"] is int
          ? data["is_login"]
          : int.tryParse(data["is_login"]?.toString() ?? "0") ?? 0,
      roleCodes: _extractRoleCodes(data),
      permissions: _extractStringList(data["permissions"]),
      planStatus: _mapOrNull(data["plan_status"] ?? data["PlanStatus"]) != null
          ? PlanStatus.fromJson(
              _mapOrNull(data["plan_status"] ?? data["PlanStatus"])!,
            )
          : null,
      expiry: _mapOrNull(data["expiry"] ?? data["Expiry"]) != null
          ? ExpiryInfo.fromJson(_mapOrNull(data["expiry"] ?? data["Expiry"])!)
          : null,
      subscription:
          _mapOrNull(data["subscription"] ?? data["Subscription"]) != null
          ? SubscriptionInfo.fromJson(
              _mapOrNull(data["subscription"] ?? data["Subscription"])!,
            )
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
      roleCodes: const [],
      permissions: const [],
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
    "roles": roleCodes,
    "permissions": permissions,
    "plan_status": planStatus?.toJson(),
    "expiry": expiry?.toJson(),
    "subscription": subscription?.toJson(),
  };

  static List<String> _extractRoleCodes(Map<String, dynamic> data) {
    final rawRoles = data["roles"];
    if (rawRoles is! List) return const [];
    final out = <String>[];
    for (final item in rawRoles) {
      if (item is Map) {
        final code = (item["RoleCode"] ?? item["role_code"] ?? "")
            .toString()
            .trim()
            .toUpperCase();
        if (code.isNotEmpty) out.add(code);
      } else {
        final code = item.toString().trim().toUpperCase();
        if (code.isNotEmpty) out.add(code);
      }
    }
    return out.toSet().toList(growable: false);
  }

  static List<String> _extractStringList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      final value = item.toString().trim();
      if (value.isNotEmpty) out.add(value);
    }
    return out.toSet().toList(growable: false);
  }

  static Map<String, dynamic>? _mapOrNull(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String get packageStatusCode {
    final code = planStatus?.statusCode.trim().toUpperCase() ?? '';
    if (code.isNotEmpty) return code;
    if (expiry?.isExpired == true) return 'EXPIRED';
    return 'UNKNOWN';
  }

  String get packageStatusText {
    final text = planStatus?.statusText.trim() ?? '';
    if (text.isNotEmpty) return text;
    if (expiry?.isExpired == true) return 'Expired';
    return 'Status unavailable';
  }

  bool get hasPackageStatus =>
      planStatus != null || expiry != null || subscription != null;

  /// ============================================================
  /// DEBUG
  /// ============================================================
  @override
  String toString() =>
      '''
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
      statusCode:
          (json["status_code"] ?? json["StatusCode"] ?? json["Status"] ?? "")
              .toString(),
      statusText:
          (json["status_text"] ?? json["StatusText"] ?? json["status"] ?? "")
              .toString(),

      // ========================================================
      // 🔥 BACKWARD SAFE LOGIC
      // If backend does NOT send canSync → ALLOW SYNC
      // ========================================================
      canSync: _truthy(json["canSync"] ?? json["can_sync"] ?? json["CanSync"]),

      // 👉 TEMP OVERRIDE (uncomment if needed)
      // canSync: true,
    );
  }

  Map<String, dynamic> toJson() => {
    "status_code": statusCode,
    "status_text": statusText,
    "canSync": canSync ? "1" : "0",
  };

  static bool _truthy(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
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
    isExpired: _truthy(json["is_expired"] ?? json["isExpired"]),
    remainingDays:
        int.tryParse(
          (json["remaining_days"] ?? json["remainingDays"] ?? 0).toString(),
        ) ??
        0,
    message: (json["message"] ?? "").toString(),
  );

  Map<String, dynamic> toJson() => {
    "is_expired": isExpired,
    "remaining_days": remainingDays,
    "message": message,
  };

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
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

  factory SubscriptionInfo.fromJson(
    Map<String, dynamic> json,
  ) => SubscriptionInfo(
    planTitle: (json["plan_title"] ?? json["planTitle"] ?? "").toString(),
    planDescription: (json["plan_description"] ?? json["planDescription"] ?? "")
        .toString(),
    planPrice: (json["plan_price"] ?? json["planPrice"] ?? "").toString(),
    durationMonths: (json["duration_months"] ?? json["durationMonths"] ?? "")
        .toString(),
    startDate: (json["start_date"] ?? json["startDate"] ?? "").toString(),
    endDate: (json["end_date"] ?? json["endDate"] ?? "").toString(),
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

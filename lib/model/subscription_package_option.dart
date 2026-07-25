class SubscriptionPackageOption {
  final int packageId;
  final String packageCode;
  final String packageName;
  final String description;
  final int durationDays;
  final double price;
  final String currency;
  final String priceText;
  final int? maxCompanies;
  final int? maxUsers;

  const SubscriptionPackageOption({
    required this.packageId,
    required this.packageCode,
    required this.packageName,
    required this.description,
    required this.durationDays,
    required this.price,
    required this.currency,
    required this.priceText,
    this.maxCompanies,
    this.maxUsers,
  });

  factory SubscriptionPackageOption.fromJson(Map<String, dynamic> json) {
    final price = _toDouble(json['price'] ?? json['Price']);
    final currency = (json['currency'] ?? json['Currency'] ?? 'PKR')
        .toString()
        .trim()
        .toUpperCase();
    final rawPriceText = (json['price_text'] ?? json['PriceText'] ?? '')
        .toString()
        .trim();

    return SubscriptionPackageOption(
      packageId: _toInt(json['package_id'] ?? json['PackageID']),
      packageCode: (json['package_code'] ?? json['PackageCode'] ?? '')
          .toString()
          .trim(),
      packageName: (json['package_name'] ?? json['PackageName'] ?? '')
          .toString()
          .trim(),
      description: (json['description'] ?? json['Description'] ?? '')
          .toString()
          .trim(),
      durationDays: _toInt(json['duration_days'] ?? json['DurationDays']),
      price: price,
      currency: currency.isEmpty ? 'PKR' : currency,
      priceText: rawPriceText.isNotEmpty
          ? rawPriceText
          : (price <= 0
                ? 'Free'
                : '${currency.isEmpty ? 'PKR' : currency} ${price.toStringAsFixed(2)}'),
      maxCompanies: _toNullableInt(
        json['max_companies'] ?? json['MaxCompanies'],
      ),
      maxUsers: _toNullableInt(json['max_users'] ?? json['MaxUsers']),
    );
  }

  String get title => packageName.isEmpty ? packageCode : packageName;

  String get subtitle {
    if (description.isNotEmpty) return description;
    final parts = <String>[];
    if (durationDays > 0) {
      parts.add(durationDays == 30 ? 'Monthly access' : '$durationDays days');
    }
    if (maxUsers != null && maxUsers! > 0) {
      parts.add(maxUsers == 1 ? '1 user' : '$maxUsers users');
    }
    if (maxCompanies != null && maxCompanies! > 0) {
      parts.add(maxCompanies == 1 ? '1 company' : '$maxCompanies companies');
    }
    return parts.isEmpty ? 'Package managed by admin' : parts.join(' • ');
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _toInt(value);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

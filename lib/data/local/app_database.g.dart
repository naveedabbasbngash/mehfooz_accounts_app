// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccPersonalTable extends AccPersonal
    with TableInfo<$AccPersonalTable, AccPersonalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccPersonalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accIdMeta = const VerificationMeta('accId');
  @override
  late final GeneratedColumn<int> accId = GeneratedColumn<int>(
    'AccID',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rDateMeta = const VerificationMeta('rDate');
  @override
  late final GeneratedColumn<String> rDate = GeneratedColumn<String>(
    'RDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'Name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'Phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _faxMeta = const VerificationMeta('fax');
  @override
  late final GeneratedColumn<String> fax = GeneratedColumn<String>(
    'Fax',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'Address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'Description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uAccNameMeta = const VerificationMeta(
    'uAccName',
  );
  @override
  late final GeneratedColumn<String> uAccName = GeneratedColumn<String>(
    'UAccName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusgMeta = const VerificationMeta(
    'statusg',
  );
  @override
  late final GeneratedColumn<String> statusg = GeneratedColumn<String>(
    'statusg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'UserID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<int> companyId = GeneratedColumn<int>(
    'CompanyID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wNameMeta = const VerificationMeta('wName');
  @override
  late final GeneratedColumn<String> wName = GeneratedColumn<String>(
    'WName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<int> isSynced = GeneratedColumn<int>(
    'IsSynced',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'UpdatedAt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<int> isDeleted = GeneratedColumn<int>(
    'IsDeleted',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accId,
    rDate,
    name,
    phone,
    fax,
    address,
    description,
    uAccName,
    statusg,
    userId,
    companyId,
    wName,
    isSynced,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Acc_Personal';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccPersonalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('AccID')) {
      context.handle(
        _accIdMeta,
        accId.isAcceptableOrUnknown(data['AccID']!, _accIdMeta),
      );
    }
    if (data.containsKey('RDate')) {
      context.handle(
        _rDateMeta,
        rDate.isAcceptableOrUnknown(data['RDate']!, _rDateMeta),
      );
    }
    if (data.containsKey('Name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['Name']!, _nameMeta),
      );
    }
    if (data.containsKey('Phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['Phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('Fax')) {
      context.handle(
        _faxMeta,
        fax.isAcceptableOrUnknown(data['Fax']!, _faxMeta),
      );
    }
    if (data.containsKey('Address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['Address']!, _addressMeta),
      );
    }
    if (data.containsKey('Description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['Description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('UAccName')) {
      context.handle(
        _uAccNameMeta,
        uAccName.isAcceptableOrUnknown(data['UAccName']!, _uAccNameMeta),
      );
    }
    if (data.containsKey('statusg')) {
      context.handle(
        _statusgMeta,
        statusg.isAcceptableOrUnknown(data['statusg']!, _statusgMeta),
      );
    }
    if (data.containsKey('UserID')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['UserID']!, _userIdMeta),
      );
    }
    if (data.containsKey('CompanyID')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['CompanyID']!, _companyIdMeta),
      );
    }
    if (data.containsKey('WName')) {
      context.handle(
        _wNameMeta,
        wName.isAcceptableOrUnknown(data['WName']!, _wNameMeta),
      );
    }
    if (data.containsKey('IsSynced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['IsSynced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('UpdatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['UpdatedAt']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('IsDeleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['IsDeleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accId};
  @override
  AccPersonalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccPersonalData(
      accId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}AccID'],
      )!,
      rDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}RDate'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Name'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Phone'],
      ),
      fax: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Fax'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Address'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Description'],
      ),
      uAccName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}UAccName'],
      ),
      statusg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statusg'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}UserID'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}CompanyID'],
      ),
      wName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}WName'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}IsSynced'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}UpdatedAt'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}IsDeleted'],
      ),
    );
  }

  @override
  $AccPersonalTable createAlias(String alias) {
    return $AccPersonalTable(attachedDatabase, alias);
  }
}

class AccPersonalData extends DataClass implements Insertable<AccPersonalData> {
  final int accId;
  final String? rDate;
  final String? name;
  final String? phone;
  final String? fax;
  final String? address;
  final String? description;
  final String? uAccName;

  /// YOUR DB stores this as TEXT (you confirmed)
  final String? statusg;
  final int? userId;
  final int? companyId;
  final String? wName;
  final int? isSynced;
  final String? updatedAt;
  final int? isDeleted;
  const AccPersonalData({
    required this.accId,
    this.rDate,
    this.name,
    this.phone,
    this.fax,
    this.address,
    this.description,
    this.uAccName,
    this.statusg,
    this.userId,
    this.companyId,
    this.wName,
    this.isSynced,
    this.updatedAt,
    this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['AccID'] = Variable<int>(accId);
    if (!nullToAbsent || rDate != null) {
      map['RDate'] = Variable<String>(rDate);
    }
    if (!nullToAbsent || name != null) {
      map['Name'] = Variable<String>(name);
    }
    if (!nullToAbsent || phone != null) {
      map['Phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || fax != null) {
      map['Fax'] = Variable<String>(fax);
    }
    if (!nullToAbsent || address != null) {
      map['Address'] = Variable<String>(address);
    }
    if (!nullToAbsent || description != null) {
      map['Description'] = Variable<String>(description);
    }
    if (!nullToAbsent || uAccName != null) {
      map['UAccName'] = Variable<String>(uAccName);
    }
    if (!nullToAbsent || statusg != null) {
      map['statusg'] = Variable<String>(statusg);
    }
    if (!nullToAbsent || userId != null) {
      map['UserID'] = Variable<int>(userId);
    }
    if (!nullToAbsent || companyId != null) {
      map['CompanyID'] = Variable<int>(companyId);
    }
    if (!nullToAbsent || wName != null) {
      map['WName'] = Variable<String>(wName);
    }
    if (!nullToAbsent || isSynced != null) {
      map['IsSynced'] = Variable<int>(isSynced);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['UpdatedAt'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || isDeleted != null) {
      map['IsDeleted'] = Variable<int>(isDeleted);
    }
    return map;
  }

  AccPersonalCompanion toCompanion(bool nullToAbsent) {
    return AccPersonalCompanion(
      accId: Value(accId),
      rDate: rDate == null && nullToAbsent
          ? const Value.absent()
          : Value(rDate),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      fax: fax == null && nullToAbsent ? const Value.absent() : Value(fax),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      uAccName: uAccName == null && nullToAbsent
          ? const Value.absent()
          : Value(uAccName),
      statusg: statusg == null && nullToAbsent
          ? const Value.absent()
          : Value(statusg),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      wName: wName == null && nullToAbsent
          ? const Value.absent()
          : Value(wName),
      isSynced: isSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: isDeleted == null && nullToAbsent
          ? const Value.absent()
          : Value(isDeleted),
    );
  }

  factory AccPersonalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccPersonalData(
      accId: serializer.fromJson<int>(json['accId']),
      rDate: serializer.fromJson<String?>(json['rDate']),
      name: serializer.fromJson<String?>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      fax: serializer.fromJson<String?>(json['fax']),
      address: serializer.fromJson<String?>(json['address']),
      description: serializer.fromJson<String?>(json['description']),
      uAccName: serializer.fromJson<String?>(json['uAccName']),
      statusg: serializer.fromJson<String?>(json['statusg']),
      userId: serializer.fromJson<int?>(json['userId']),
      companyId: serializer.fromJson<int?>(json['companyId']),
      wName: serializer.fromJson<String?>(json['wName']),
      isSynced: serializer.fromJson<int?>(json['isSynced']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      isDeleted: serializer.fromJson<int?>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accId': serializer.toJson<int>(accId),
      'rDate': serializer.toJson<String?>(rDate),
      'name': serializer.toJson<String?>(name),
      'phone': serializer.toJson<String?>(phone),
      'fax': serializer.toJson<String?>(fax),
      'address': serializer.toJson<String?>(address),
      'description': serializer.toJson<String?>(description),
      'uAccName': serializer.toJson<String?>(uAccName),
      'statusg': serializer.toJson<String?>(statusg),
      'userId': serializer.toJson<int?>(userId),
      'companyId': serializer.toJson<int?>(companyId),
      'wName': serializer.toJson<String?>(wName),
      'isSynced': serializer.toJson<int?>(isSynced),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'isDeleted': serializer.toJson<int?>(isDeleted),
    };
  }

  AccPersonalData copyWith({
    int? accId,
    Value<String?> rDate = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> fax = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> uAccName = const Value.absent(),
    Value<String?> statusg = const Value.absent(),
    Value<int?> userId = const Value.absent(),
    Value<int?> companyId = const Value.absent(),
    Value<String?> wName = const Value.absent(),
    Value<int?> isSynced = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<int?> isDeleted = const Value.absent(),
  }) => AccPersonalData(
    accId: accId ?? this.accId,
    rDate: rDate.present ? rDate.value : this.rDate,
    name: name.present ? name.value : this.name,
    phone: phone.present ? phone.value : this.phone,
    fax: fax.present ? fax.value : this.fax,
    address: address.present ? address.value : this.address,
    description: description.present ? description.value : this.description,
    uAccName: uAccName.present ? uAccName.value : this.uAccName,
    statusg: statusg.present ? statusg.value : this.statusg,
    userId: userId.present ? userId.value : this.userId,
    companyId: companyId.present ? companyId.value : this.companyId,
    wName: wName.present ? wName.value : this.wName,
    isSynced: isSynced.present ? isSynced.value : this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted.present ? isDeleted.value : this.isDeleted,
  );
  AccPersonalData copyWithCompanion(AccPersonalCompanion data) {
    return AccPersonalData(
      accId: data.accId.present ? data.accId.value : this.accId,
      rDate: data.rDate.present ? data.rDate.value : this.rDate,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      fax: data.fax.present ? data.fax.value : this.fax,
      address: data.address.present ? data.address.value : this.address,
      description: data.description.present
          ? data.description.value
          : this.description,
      uAccName: data.uAccName.present ? data.uAccName.value : this.uAccName,
      statusg: data.statusg.present ? data.statusg.value : this.statusg,
      userId: data.userId.present ? data.userId.value : this.userId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      wName: data.wName.present ? data.wName.value : this.wName,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccPersonalData(')
          ..write('accId: $accId, ')
          ..write('rDate: $rDate, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('fax: $fax, ')
          ..write('address: $address, ')
          ..write('description: $description, ')
          ..write('uAccName: $uAccName, ')
          ..write('statusg: $statusg, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accId,
    rDate,
    name,
    phone,
    fax,
    address,
    description,
    uAccName,
    statusg,
    userId,
    companyId,
    wName,
    isSynced,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccPersonalData &&
          other.accId == this.accId &&
          other.rDate == this.rDate &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.fax == this.fax &&
          other.address == this.address &&
          other.description == this.description &&
          other.uAccName == this.uAccName &&
          other.statusg == this.statusg &&
          other.userId == this.userId &&
          other.companyId == this.companyId &&
          other.wName == this.wName &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class AccPersonalCompanion extends UpdateCompanion<AccPersonalData> {
  final Value<int> accId;
  final Value<String?> rDate;
  final Value<String?> name;
  final Value<String?> phone;
  final Value<String?> fax;
  final Value<String?> address;
  final Value<String?> description;
  final Value<String?> uAccName;
  final Value<String?> statusg;
  final Value<int?> userId;
  final Value<int?> companyId;
  final Value<String?> wName;
  final Value<int?> isSynced;
  final Value<String?> updatedAt;
  final Value<int?> isDeleted;
  const AccPersonalCompanion({
    this.accId = const Value.absent(),
    this.rDate = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.fax = const Value.absent(),
    this.address = const Value.absent(),
    this.description = const Value.absent(),
    this.uAccName = const Value.absent(),
    this.statusg = const Value.absent(),
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  AccPersonalCompanion.insert({
    this.accId = const Value.absent(),
    this.rDate = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.fax = const Value.absent(),
    this.address = const Value.absent(),
    this.description = const Value.absent(),
    this.uAccName = const Value.absent(),
    this.statusg = const Value.absent(),
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  static Insertable<AccPersonalData> custom({
    Expression<int>? accId,
    Expression<String>? rDate,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? fax,
    Expression<String>? address,
    Expression<String>? description,
    Expression<String>? uAccName,
    Expression<String>? statusg,
    Expression<int>? userId,
    Expression<int>? companyId,
    Expression<String>? wName,
    Expression<int>? isSynced,
    Expression<String>? updatedAt,
    Expression<int>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (accId != null) 'AccID': accId,
      if (rDate != null) 'RDate': rDate,
      if (name != null) 'Name': name,
      if (phone != null) 'Phone': phone,
      if (fax != null) 'Fax': fax,
      if (address != null) 'Address': address,
      if (description != null) 'Description': description,
      if (uAccName != null) 'UAccName': uAccName,
      if (statusg != null) 'statusg': statusg,
      if (userId != null) 'UserID': userId,
      if (companyId != null) 'CompanyID': companyId,
      if (wName != null) 'WName': wName,
      if (isSynced != null) 'IsSynced': isSynced,
      if (updatedAt != null) 'UpdatedAt': updatedAt,
      if (isDeleted != null) 'IsDeleted': isDeleted,
    });
  }

  AccPersonalCompanion copyWith({
    Value<int>? accId,
    Value<String?>? rDate,
    Value<String?>? name,
    Value<String?>? phone,
    Value<String?>? fax,
    Value<String?>? address,
    Value<String?>? description,
    Value<String?>? uAccName,
    Value<String?>? statusg,
    Value<int?>? userId,
    Value<int?>? companyId,
    Value<String?>? wName,
    Value<int?>? isSynced,
    Value<String?>? updatedAt,
    Value<int?>? isDeleted,
  }) {
    return AccPersonalCompanion(
      accId: accId ?? this.accId,
      rDate: rDate ?? this.rDate,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      fax: fax ?? this.fax,
      address: address ?? this.address,
      description: description ?? this.description,
      uAccName: uAccName ?? this.uAccName,
      statusg: statusg ?? this.statusg,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      wName: wName ?? this.wName,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accId.present) {
      map['AccID'] = Variable<int>(accId.value);
    }
    if (rDate.present) {
      map['RDate'] = Variable<String>(rDate.value);
    }
    if (name.present) {
      map['Name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['Phone'] = Variable<String>(phone.value);
    }
    if (fax.present) {
      map['Fax'] = Variable<String>(fax.value);
    }
    if (address.present) {
      map['Address'] = Variable<String>(address.value);
    }
    if (description.present) {
      map['Description'] = Variable<String>(description.value);
    }
    if (uAccName.present) {
      map['UAccName'] = Variable<String>(uAccName.value);
    }
    if (statusg.present) {
      map['statusg'] = Variable<String>(statusg.value);
    }
    if (userId.present) {
      map['UserID'] = Variable<int>(userId.value);
    }
    if (companyId.present) {
      map['CompanyID'] = Variable<int>(companyId.value);
    }
    if (wName.present) {
      map['WName'] = Variable<String>(wName.value);
    }
    if (isSynced.present) {
      map['IsSynced'] = Variable<int>(isSynced.value);
    }
    if (updatedAt.present) {
      map['UpdatedAt'] = Variable<String>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['IsDeleted'] = Variable<int>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccPersonalCompanion(')
          ..write('accId: $accId, ')
          ..write('rDate: $rDate, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('fax: $fax, ')
          ..write('address: $address, ')
          ..write('description: $description, ')
          ..write('uAccName: $uAccName, ')
          ..write('statusg: $statusg, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $AccTypeTable extends AccType with TableInfo<$AccTypeTable, AccTypeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccTypeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accTypeIdMeta = const VerificationMeta(
    'accTypeId',
  );
  @override
  late final GeneratedColumn<int> accTypeId = GeneratedColumn<int>(
    'AccTypeID',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accTypeNameMeta = const VerificationMeta(
    'accTypeName',
  );
  @override
  late final GeneratedColumn<String> accTypeName = GeneratedColumn<String>(
    'AccTypeName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accTypeNameUMeta = const VerificationMeta(
    'accTypeNameU',
  );
  @override
  late final GeneratedColumn<String> accTypeNameU = GeneratedColumn<String>(
    'AccTypeNameu',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagMeta = const VerificationMeta('flag');
  @override
  late final GeneratedColumn<String> flag = GeneratedColumn<String>(
    'FLAG',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<int> isSynced = GeneratedColumn<int>(
    'IsSynced',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'UpdatedAt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accTypeId,
    accTypeName,
    accTypeNameU,
    flag,
    isSynced,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'AccType';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccTypeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('AccTypeID')) {
      context.handle(
        _accTypeIdMeta,
        accTypeId.isAcceptableOrUnknown(data['AccTypeID']!, _accTypeIdMeta),
      );
    }
    if (data.containsKey('AccTypeName')) {
      context.handle(
        _accTypeNameMeta,
        accTypeName.isAcceptableOrUnknown(
          data['AccTypeName']!,
          _accTypeNameMeta,
        ),
      );
    }
    if (data.containsKey('AccTypeNameu')) {
      context.handle(
        _accTypeNameUMeta,
        accTypeNameU.isAcceptableOrUnknown(
          data['AccTypeNameu']!,
          _accTypeNameUMeta,
        ),
      );
    }
    if (data.containsKey('FLAG')) {
      context.handle(
        _flagMeta,
        flag.isAcceptableOrUnknown(data['FLAG']!, _flagMeta),
      );
    }
    if (data.containsKey('IsSynced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['IsSynced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('UpdatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['UpdatedAt']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accTypeId};
  @override
  AccTypeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccTypeData(
      accTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}AccTypeID'],
      )!,
      accTypeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}AccTypeName'],
      ),
      accTypeNameU: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}AccTypeNameu'],
      ),
      flag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}FLAG'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}IsSynced'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}UpdatedAt'],
      ),
    );
  }

  @override
  $AccTypeTable createAlias(String alias) {
    return $AccTypeTable(attachedDatabase, alias);
  }
}

class AccTypeData extends DataClass implements Insertable<AccTypeData> {
  final int accTypeId;
  final String? accTypeName;
  final String? accTypeNameU;
  final String? flag;
  final int? isSynced;
  final String? updatedAt;
  const AccTypeData({
    required this.accTypeId,
    this.accTypeName,
    this.accTypeNameU,
    this.flag,
    this.isSynced,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['AccTypeID'] = Variable<int>(accTypeId);
    if (!nullToAbsent || accTypeName != null) {
      map['AccTypeName'] = Variable<String>(accTypeName);
    }
    if (!nullToAbsent || accTypeNameU != null) {
      map['AccTypeNameu'] = Variable<String>(accTypeNameU);
    }
    if (!nullToAbsent || flag != null) {
      map['FLAG'] = Variable<String>(flag);
    }
    if (!nullToAbsent || isSynced != null) {
      map['IsSynced'] = Variable<int>(isSynced);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['UpdatedAt'] = Variable<String>(updatedAt);
    }
    return map;
  }

  AccTypeCompanion toCompanion(bool nullToAbsent) {
    return AccTypeCompanion(
      accTypeId: Value(accTypeId),
      accTypeName: accTypeName == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeName),
      accTypeNameU: accTypeNameU == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeNameU),
      flag: flag == null && nullToAbsent ? const Value.absent() : Value(flag),
      isSynced: isSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AccTypeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccTypeData(
      accTypeId: serializer.fromJson<int>(json['accTypeId']),
      accTypeName: serializer.fromJson<String?>(json['accTypeName']),
      accTypeNameU: serializer.fromJson<String?>(json['accTypeNameU']),
      flag: serializer.fromJson<String?>(json['flag']),
      isSynced: serializer.fromJson<int?>(json['isSynced']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accTypeId': serializer.toJson<int>(accTypeId),
      'accTypeName': serializer.toJson<String?>(accTypeName),
      'accTypeNameU': serializer.toJson<String?>(accTypeNameU),
      'flag': serializer.toJson<String?>(flag),
      'isSynced': serializer.toJson<int?>(isSynced),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  AccTypeData copyWith({
    int? accTypeId,
    Value<String?> accTypeName = const Value.absent(),
    Value<String?> accTypeNameU = const Value.absent(),
    Value<String?> flag = const Value.absent(),
    Value<int?> isSynced = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => AccTypeData(
    accTypeId: accTypeId ?? this.accTypeId,
    accTypeName: accTypeName.present ? accTypeName.value : this.accTypeName,
    accTypeNameU: accTypeNameU.present ? accTypeNameU.value : this.accTypeNameU,
    flag: flag.present ? flag.value : this.flag,
    isSynced: isSynced.present ? isSynced.value : this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AccTypeData copyWithCompanion(AccTypeCompanion data) {
    return AccTypeData(
      accTypeId: data.accTypeId.present ? data.accTypeId.value : this.accTypeId,
      accTypeName: data.accTypeName.present
          ? data.accTypeName.value
          : this.accTypeName,
      accTypeNameU: data.accTypeNameU.present
          ? data.accTypeNameU.value
          : this.accTypeNameU,
      flag: data.flag.present ? data.flag.value : this.flag,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccTypeData(')
          ..write('accTypeId: $accTypeId, ')
          ..write('accTypeName: $accTypeName, ')
          ..write('accTypeNameU: $accTypeNameU, ')
          ..write('flag: $flag, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accTypeId,
    accTypeName,
    accTypeNameU,
    flag,
    isSynced,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccTypeData &&
          other.accTypeId == this.accTypeId &&
          other.accTypeName == this.accTypeName &&
          other.accTypeNameU == this.accTypeNameU &&
          other.flag == this.flag &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt);
}

class AccTypeCompanion extends UpdateCompanion<AccTypeData> {
  final Value<int> accTypeId;
  final Value<String?> accTypeName;
  final Value<String?> accTypeNameU;
  final Value<String?> flag;
  final Value<int?> isSynced;
  final Value<String?> updatedAt;
  const AccTypeCompanion({
    this.accTypeId = const Value.absent(),
    this.accTypeName = const Value.absent(),
    this.accTypeNameU = const Value.absent(),
    this.flag = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AccTypeCompanion.insert({
    this.accTypeId = const Value.absent(),
    this.accTypeName = const Value.absent(),
    this.accTypeNameU = const Value.absent(),
    this.flag = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<AccTypeData> custom({
    Expression<int>? accTypeId,
    Expression<String>? accTypeName,
    Expression<String>? accTypeNameU,
    Expression<String>? flag,
    Expression<int>? isSynced,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (accTypeId != null) 'AccTypeID': accTypeId,
      if (accTypeName != null) 'AccTypeName': accTypeName,
      if (accTypeNameU != null) 'AccTypeNameu': accTypeNameU,
      if (flag != null) 'FLAG': flag,
      if (isSynced != null) 'IsSynced': isSynced,
      if (updatedAt != null) 'UpdatedAt': updatedAt,
    });
  }

  AccTypeCompanion copyWith({
    Value<int>? accTypeId,
    Value<String?>? accTypeName,
    Value<String?>? accTypeNameU,
    Value<String?>? flag,
    Value<int?>? isSynced,
    Value<String?>? updatedAt,
  }) {
    return AccTypeCompanion(
      accTypeId: accTypeId ?? this.accTypeId,
      accTypeName: accTypeName ?? this.accTypeName,
      accTypeNameU: accTypeNameU ?? this.accTypeNameU,
      flag: flag ?? this.flag,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accTypeId.present) {
      map['AccTypeID'] = Variable<int>(accTypeId.value);
    }
    if (accTypeName.present) {
      map['AccTypeName'] = Variable<String>(accTypeName.value);
    }
    if (accTypeNameU.present) {
      map['AccTypeNameu'] = Variable<String>(accTypeNameU.value);
    }
    if (flag.present) {
      map['FLAG'] = Variable<String>(flag.value);
    }
    if (isSynced.present) {
      map['IsSynced'] = Variable<int>(isSynced.value);
    }
    if (updatedAt.present) {
      map['UpdatedAt'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccTypeCompanion(')
          ..write('accTypeId: $accTypeId, ')
          ..write('accTypeName: $accTypeName, ')
          ..write('accTypeNameU: $accTypeNameU, ')
          ..write('flag: $flag, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CompanyTableTable extends CompanyTable
    with TableInfo<$CompanyTableTable, CompanyTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompanyTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<int> companyId = GeneratedColumn<int>(
    'CompanyID',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'CompanyName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarksMeta = const VerificationMeta(
    'remarks',
  );
  @override
  late final GeneratedColumn<String> remarks = GeneratedColumn<String>(
    'Remarks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [companyId, companyName, remarks];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Company';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompanyTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('CompanyID')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['CompanyID']!, _companyIdMeta),
      );
    }
    if (data.containsKey('CompanyName')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['CompanyName']!,
          _companyNameMeta,
        ),
      );
    }
    if (data.containsKey('Remarks')) {
      context.handle(
        _remarksMeta,
        remarks.isAcceptableOrUnknown(data['Remarks']!, _remarksMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {companyId};
  @override
  CompanyTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompanyTableData(
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}CompanyID'],
      )!,
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}CompanyName'],
      ),
      remarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Remarks'],
      ),
    );
  }

  @override
  $CompanyTableTable createAlias(String alias) {
    return $CompanyTableTable(attachedDatabase, alias);
  }
}

class CompanyTableData extends DataClass
    implements Insertable<CompanyTableData> {
  final int companyId;
  final String? companyName;
  final String? remarks;
  const CompanyTableData({
    required this.companyId,
    this.companyName,
    this.remarks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['CompanyID'] = Variable<int>(companyId);
    if (!nullToAbsent || companyName != null) {
      map['CompanyName'] = Variable<String>(companyName);
    }
    if (!nullToAbsent || remarks != null) {
      map['Remarks'] = Variable<String>(remarks);
    }
    return map;
  }

  CompanyTableCompanion toCompanion(bool nullToAbsent) {
    return CompanyTableCompanion(
      companyId: Value(companyId),
      companyName: companyName == null && nullToAbsent
          ? const Value.absent()
          : Value(companyName),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
    );
  }

  factory CompanyTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompanyTableData(
      companyId: serializer.fromJson<int>(json['companyId']),
      companyName: serializer.fromJson<String?>(json['companyName']),
      remarks: serializer.fromJson<String?>(json['remarks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<int>(companyId),
      'companyName': serializer.toJson<String?>(companyName),
      'remarks': serializer.toJson<String?>(remarks),
    };
  }

  CompanyTableData copyWith({
    int? companyId,
    Value<String?> companyName = const Value.absent(),
    Value<String?> remarks = const Value.absent(),
  }) => CompanyTableData(
    companyId: companyId ?? this.companyId,
    companyName: companyName.present ? companyName.value : this.companyName,
    remarks: remarks.present ? remarks.value : this.remarks,
  );
  CompanyTableData copyWithCompanion(CompanyTableCompanion data) {
    return CompanyTableData(
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompanyTableData(')
          ..write('companyId: $companyId, ')
          ..write('companyName: $companyName, ')
          ..write('remarks: $remarks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(companyId, companyName, remarks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompanyTableData &&
          other.companyId == this.companyId &&
          other.companyName == this.companyName &&
          other.remarks == this.remarks);
}

class CompanyTableCompanion extends UpdateCompanion<CompanyTableData> {
  final Value<int> companyId;
  final Value<String?> companyName;
  final Value<String?> remarks;
  const CompanyTableCompanion({
    this.companyId = const Value.absent(),
    this.companyName = const Value.absent(),
    this.remarks = const Value.absent(),
  });
  CompanyTableCompanion.insert({
    this.companyId = const Value.absent(),
    this.companyName = const Value.absent(),
    this.remarks = const Value.absent(),
  });
  static Insertable<CompanyTableData> custom({
    Expression<int>? companyId,
    Expression<String>? companyName,
    Expression<String>? remarks,
  }) {
    return RawValuesInsertable({
      if (companyId != null) 'CompanyID': companyId,
      if (companyName != null) 'CompanyName': companyName,
      if (remarks != null) 'Remarks': remarks,
    });
  }

  CompanyTableCompanion copyWith({
    Value<int>? companyId,
    Value<String?>? companyName,
    Value<String?>? remarks,
  }) {
    return CompanyTableCompanion(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (companyId.present) {
      map['CompanyID'] = Variable<int>(companyId.value);
    }
    if (companyName.present) {
      map['CompanyName'] = Variable<String>(companyName.value);
    }
    if (remarks.present) {
      map['Remarks'] = Variable<String>(remarks.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompanyTableCompanion(')
          ..write('companyId: $companyId, ')
          ..write('companyName: $companyName, ')
          ..write('remarks: $remarks')
          ..write(')'))
        .toString();
  }
}

class $DbInfoTableTable extends DbInfoTable
    with TableInfo<$DbInfoTableTable, DbInfoTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbInfoTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _emailAddressMeta = const VerificationMeta(
    'emailAddress',
  );
  @override
  late final GeneratedColumn<String> emailAddress = GeneratedColumn<String>(
    'email_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _databaseNameMeta = const VerificationMeta(
    'databaseName',
  );
  @override
  late final GeneratedColumn<String> databaseName = GeneratedColumn<String>(
    'database_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [emailAddress, databaseName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Db_Info';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbInfoTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('email_address')) {
      context.handle(
        _emailAddressMeta,
        emailAddress.isAcceptableOrUnknown(
          data['email_address']!,
          _emailAddressMeta,
        ),
      );
    }
    if (data.containsKey('database_name')) {
      context.handle(
        _databaseNameMeta,
        databaseName.isAcceptableOrUnknown(
          data['database_name']!,
          _databaseNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  DbInfoTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbInfoTableData(
      emailAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email_address'],
      ),
      databaseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}database_name'],
      ),
    );
  }

  @override
  $DbInfoTableTable createAlias(String alias) {
    return $DbInfoTableTable(attachedDatabase, alias);
  }
}

class DbInfoTableData extends DataClass implements Insertable<DbInfoTableData> {
  final String? emailAddress;
  final String? databaseName;
  const DbInfoTableData({this.emailAddress, this.databaseName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || emailAddress != null) {
      map['email_address'] = Variable<String>(emailAddress);
    }
    if (!nullToAbsent || databaseName != null) {
      map['database_name'] = Variable<String>(databaseName);
    }
    return map;
  }

  DbInfoTableCompanion toCompanion(bool nullToAbsent) {
    return DbInfoTableCompanion(
      emailAddress: emailAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(emailAddress),
      databaseName: databaseName == null && nullToAbsent
          ? const Value.absent()
          : Value(databaseName),
    );
  }

  factory DbInfoTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbInfoTableData(
      emailAddress: serializer.fromJson<String?>(json['emailAddress']),
      databaseName: serializer.fromJson<String?>(json['databaseName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'emailAddress': serializer.toJson<String?>(emailAddress),
      'databaseName': serializer.toJson<String?>(databaseName),
    };
  }

  DbInfoTableData copyWith({
    Value<String?> emailAddress = const Value.absent(),
    Value<String?> databaseName = const Value.absent(),
  }) => DbInfoTableData(
    emailAddress: emailAddress.present ? emailAddress.value : this.emailAddress,
    databaseName: databaseName.present ? databaseName.value : this.databaseName,
  );
  DbInfoTableData copyWithCompanion(DbInfoTableCompanion data) {
    return DbInfoTableData(
      emailAddress: data.emailAddress.present
          ? data.emailAddress.value
          : this.emailAddress,
      databaseName: data.databaseName.present
          ? data.databaseName.value
          : this.databaseName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbInfoTableData(')
          ..write('emailAddress: $emailAddress, ')
          ..write('databaseName: $databaseName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(emailAddress, databaseName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbInfoTableData &&
          other.emailAddress == this.emailAddress &&
          other.databaseName == this.databaseName);
}

class DbInfoTableCompanion extends UpdateCompanion<DbInfoTableData> {
  final Value<String?> emailAddress;
  final Value<String?> databaseName;
  final Value<int> rowid;
  const DbInfoTableCompanion({
    this.emailAddress = const Value.absent(),
    this.databaseName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbInfoTableCompanion.insert({
    this.emailAddress = const Value.absent(),
    this.databaseName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<DbInfoTableData> custom({
    Expression<String>? emailAddress,
    Expression<String>? databaseName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (emailAddress != null) 'email_address': emailAddress,
      if (databaseName != null) 'database_name': databaseName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbInfoTableCompanion copyWith({
    Value<String?>? emailAddress,
    Value<String?>? databaseName,
    Value<int>? rowid,
  }) {
    return DbInfoTableCompanion(
      emailAddress: emailAddress ?? this.emailAddress,
      databaseName: databaseName ?? this.databaseName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (emailAddress.present) {
      map['email_address'] = Variable<String>(emailAddress.value);
    }
    if (databaseName.present) {
      map['database_name'] = Variable<String>(databaseName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbInfoTableCompanion(')
          ..write('emailAddress: $emailAddress, ')
          ..write('databaseName: $databaseName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsPTable extends TransactionsP
    with TableInfo<$TransactionsPTable, TransactionsPData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsPTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _voucherNoMeta = const VerificationMeta(
    'voucherNo',
  );
  @override
  late final GeneratedColumn<double> voucherNo = GeneratedColumn<double>(
    'VoucherNo',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tDateMeta = const VerificationMeta('tDate');
  @override
  late final GeneratedColumn<String> tDate = GeneratedColumn<String>(
    'TDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accIdMeta = const VerificationMeta('accId');
  @override
  late final GeneratedColumn<int> accId = GeneratedColumn<int>(
    'AccID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accTypeIdMeta = const VerificationMeta(
    'accTypeId',
  );
  @override
  late final GeneratedColumn<int> accTypeId = GeneratedColumn<int>(
    'AccTypeID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'Description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _drMeta = const VerificationMeta('dr');
  @override
  late final GeneratedColumn<double> dr = GeneratedColumn<double>(
    'Dr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _crMeta = const VerificationMeta('cr');
  @override
  late final GeneratedColumn<double> cr = GeneratedColumn<double>(
    'Cr',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'Status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stMeta = const VerificationMeta('st');
  @override
  late final GeneratedColumn<String> st = GeneratedColumn<String>(
    'st',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateStatusMeta = const VerificationMeta(
    'updateStatus',
  );
  @override
  late final GeneratedColumn<String> updateStatus = GeneratedColumn<String>(
    'updatestatus',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyStatusMeta = const VerificationMeta(
    'currencyStatus',
  );
  @override
  late final GeneratedColumn<String> currencyStatus = GeneratedColumn<String>(
    'currencystatus',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashStatusMeta = const VerificationMeta(
    'cashStatus',
  );
  @override
  late final GeneratedColumn<String> cashStatus = GeneratedColumn<String>(
    'cashstatus',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'UserID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<int> companyId = GeneratedColumn<int>(
    'CompanyID',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wNameMeta = const VerificationMeta('wName');
  @override
  late final GeneratedColumn<String> wName = GeneratedColumn<String>(
    'WName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _msgNoMeta = const VerificationMeta('msgNo');
  @override
  late final GeneratedColumn<String> msgNo = GeneratedColumn<String>(
    'msgno',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hwls1Meta = const VerificationMeta('hwls1');
  @override
  late final GeneratedColumn<String> hwls1 = GeneratedColumn<String>(
    'hwls1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hwlsMeta = const VerificationMeta('hwls');
  @override
  late final GeneratedColumn<String> hwls = GeneratedColumn<String>(
    'hwls',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _advanceMessMeta = const VerificationMeta(
    'advanceMess',
  );
  @override
  late final GeneratedColumn<String> advanceMess = GeneratedColumn<String>(
    'advancemess',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cbalMeta = const VerificationMeta('cbal');
  @override
  late final GeneratedColumn<int> cbal = GeneratedColumn<int>(
    'cbal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cbal1Meta = const VerificationMeta('cbal1');
  @override
  late final GeneratedColumn<int> cbal1 = GeneratedColumn<int>(
    'cbal1',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tTimeMeta = const VerificationMeta('tTime');
  @override
  late final GeneratedColumn<String> tTime = GeneratedColumn<String>(
    'TTIME',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdMeta = const VerificationMeta('pd');
  @override
  late final GeneratedColumn<String> pd = GeneratedColumn<String>(
    'PD',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _msgNo2Meta = const VerificationMeta('msgNo2');
  @override
  late final GeneratedColumn<String> msgNo2 = GeneratedColumn<String>(
    'msgno2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _othersMeta = const VerificationMeta('others');
  @override
  late final GeneratedColumn<String> others = GeneratedColumn<String>(
    'OTHERS',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<int> isSynced = GeneratedColumn<int>(
    'IsSynced',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'UpdatedAt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<int> isDeleted = GeneratedColumn<int>(
    'IsDeleted',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    voucherNo,
    tDate,
    accId,
    accTypeId,
    description,
    dr,
    cr,
    status,
    st,
    updateStatus,
    currencyStatus,
    cashStatus,
    userId,
    companyId,
    wName,
    msgNo,
    hwls1,
    hwls,
    advanceMess,
    cbal,
    cbal1,
    tTime,
    pd,
    msgNo2,
    others,
    isSynced,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Transactions_P';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionsPData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('VoucherNo')) {
      context.handle(
        _voucherNoMeta,
        voucherNo.isAcceptableOrUnknown(data['VoucherNo']!, _voucherNoMeta),
      );
    }
    if (data.containsKey('TDate')) {
      context.handle(
        _tDateMeta,
        tDate.isAcceptableOrUnknown(data['TDate']!, _tDateMeta),
      );
    }
    if (data.containsKey('AccID')) {
      context.handle(
        _accIdMeta,
        accId.isAcceptableOrUnknown(data['AccID']!, _accIdMeta),
      );
    }
    if (data.containsKey('AccTypeID')) {
      context.handle(
        _accTypeIdMeta,
        accTypeId.isAcceptableOrUnknown(data['AccTypeID']!, _accTypeIdMeta),
      );
    }
    if (data.containsKey('Description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['Description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('Dr')) {
      context.handle(_drMeta, dr.isAcceptableOrUnknown(data['Dr']!, _drMeta));
    }
    if (data.containsKey('Cr')) {
      context.handle(_crMeta, cr.isAcceptableOrUnknown(data['Cr']!, _crMeta));
    }
    if (data.containsKey('Status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['Status']!, _statusMeta),
      );
    }
    if (data.containsKey('st')) {
      context.handle(_stMeta, st.isAcceptableOrUnknown(data['st']!, _stMeta));
    }
    if (data.containsKey('updatestatus')) {
      context.handle(
        _updateStatusMeta,
        updateStatus.isAcceptableOrUnknown(
          data['updatestatus']!,
          _updateStatusMeta,
        ),
      );
    }
    if (data.containsKey('currencystatus')) {
      context.handle(
        _currencyStatusMeta,
        currencyStatus.isAcceptableOrUnknown(
          data['currencystatus']!,
          _currencyStatusMeta,
        ),
      );
    }
    if (data.containsKey('cashstatus')) {
      context.handle(
        _cashStatusMeta,
        cashStatus.isAcceptableOrUnknown(data['cashstatus']!, _cashStatusMeta),
      );
    }
    if (data.containsKey('UserID')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['UserID']!, _userIdMeta),
      );
    }
    if (data.containsKey('CompanyID')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['CompanyID']!, _companyIdMeta),
      );
    }
    if (data.containsKey('WName')) {
      context.handle(
        _wNameMeta,
        wName.isAcceptableOrUnknown(data['WName']!, _wNameMeta),
      );
    }
    if (data.containsKey('msgno')) {
      context.handle(
        _msgNoMeta,
        msgNo.isAcceptableOrUnknown(data['msgno']!, _msgNoMeta),
      );
    }
    if (data.containsKey('hwls1')) {
      context.handle(
        _hwls1Meta,
        hwls1.isAcceptableOrUnknown(data['hwls1']!, _hwls1Meta),
      );
    }
    if (data.containsKey('hwls')) {
      context.handle(
        _hwlsMeta,
        hwls.isAcceptableOrUnknown(data['hwls']!, _hwlsMeta),
      );
    }
    if (data.containsKey('advancemess')) {
      context.handle(
        _advanceMessMeta,
        advanceMess.isAcceptableOrUnknown(
          data['advancemess']!,
          _advanceMessMeta,
        ),
      );
    }
    if (data.containsKey('cbal')) {
      context.handle(
        _cbalMeta,
        cbal.isAcceptableOrUnknown(data['cbal']!, _cbalMeta),
      );
    }
    if (data.containsKey('cbal1')) {
      context.handle(
        _cbal1Meta,
        cbal1.isAcceptableOrUnknown(data['cbal1']!, _cbal1Meta),
      );
    }
    if (data.containsKey('TTIME')) {
      context.handle(
        _tTimeMeta,
        tTime.isAcceptableOrUnknown(data['TTIME']!, _tTimeMeta),
      );
    }
    if (data.containsKey('PD')) {
      context.handle(_pdMeta, pd.isAcceptableOrUnknown(data['PD']!, _pdMeta));
    }
    if (data.containsKey('msgno2')) {
      context.handle(
        _msgNo2Meta,
        msgNo2.isAcceptableOrUnknown(data['msgno2']!, _msgNo2Meta),
      );
    }
    if (data.containsKey('OTHERS')) {
      context.handle(
        _othersMeta,
        others.isAcceptableOrUnknown(data['OTHERS']!, _othersMeta),
      );
    }
    if (data.containsKey('IsSynced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['IsSynced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('UpdatedAt')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['UpdatedAt']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('IsDeleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['IsDeleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TransactionsPData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionsPData(
      voucherNo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}VoucherNo'],
      ),
      tDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}TDate'],
      ),
      accId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}AccID'],
      ),
      accTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}AccTypeID'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Description'],
      ),
      dr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}Dr'],
      ),
      cr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}Cr'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Status'],
      ),
      st: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}st'],
      ),
      updateStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updatestatus'],
      ),
      currencyStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currencystatus'],
      ),
      cashStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashstatus'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}UserID'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}CompanyID'],
      ),
      wName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}WName'],
      ),
      msgNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}msgno'],
      ),
      hwls1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hwls1'],
      ),
      hwls: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hwls'],
      ),
      advanceMess: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}advancemess'],
      ),
      cbal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cbal'],
      ),
      cbal1: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cbal1'],
      ),
      tTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}TTIME'],
      ),
      pd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}PD'],
      ),
      msgNo2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}msgno2'],
      ),
      others: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}OTHERS'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}IsSynced'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}UpdatedAt'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}IsDeleted'],
      ),
    );
  }

  @override
  $TransactionsPTable createAlias(String alias) {
    return $TransactionsPTable(attachedDatabase, alias);
  }
}

class TransactionsPData extends DataClass
    implements Insertable<TransactionsPData> {
  final double? voucherNo;
  final String? tDate;
  final int? accId;
  final int? accTypeId;
  final String? description;
  final double? dr;
  final double? cr;

  /// These are TEXT in SQLite — must remain TEXT!
  final String? status;
  final String? st;
  final String? updateStatus;
  final String? currencyStatus;
  final String? cashStatus;
  final int? userId;
  final int? companyId;
  final String? wName;
  final String? msgNo;
  final String? hwls1;
  final String? hwls;
  final String? advanceMess;

  /// These are INTEGER in SQLite
  final int? cbal;
  final int? cbal1;
  final String? tTime;
  final String? pd;
  final String? msgNo2;
  final String? others;
  final int? isSynced;
  final String? updatedAt;
  final int? isDeleted;
  const TransactionsPData({
    this.voucherNo,
    this.tDate,
    this.accId,
    this.accTypeId,
    this.description,
    this.dr,
    this.cr,
    this.status,
    this.st,
    this.updateStatus,
    this.currencyStatus,
    this.cashStatus,
    this.userId,
    this.companyId,
    this.wName,
    this.msgNo,
    this.hwls1,
    this.hwls,
    this.advanceMess,
    this.cbal,
    this.cbal1,
    this.tTime,
    this.pd,
    this.msgNo2,
    this.others,
    this.isSynced,
    this.updatedAt,
    this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || voucherNo != null) {
      map['VoucherNo'] = Variable<double>(voucherNo);
    }
    if (!nullToAbsent || tDate != null) {
      map['TDate'] = Variable<String>(tDate);
    }
    if (!nullToAbsent || accId != null) {
      map['AccID'] = Variable<int>(accId);
    }
    if (!nullToAbsent || accTypeId != null) {
      map['AccTypeID'] = Variable<int>(accTypeId);
    }
    if (!nullToAbsent || description != null) {
      map['Description'] = Variable<String>(description);
    }
    if (!nullToAbsent || dr != null) {
      map['Dr'] = Variable<double>(dr);
    }
    if (!nullToAbsent || cr != null) {
      map['Cr'] = Variable<double>(cr);
    }
    if (!nullToAbsent || status != null) {
      map['Status'] = Variable<String>(status);
    }
    if (!nullToAbsent || st != null) {
      map['st'] = Variable<String>(st);
    }
    if (!nullToAbsent || updateStatus != null) {
      map['updatestatus'] = Variable<String>(updateStatus);
    }
    if (!nullToAbsent || currencyStatus != null) {
      map['currencystatus'] = Variable<String>(currencyStatus);
    }
    if (!nullToAbsent || cashStatus != null) {
      map['cashstatus'] = Variable<String>(cashStatus);
    }
    if (!nullToAbsent || userId != null) {
      map['UserID'] = Variable<int>(userId);
    }
    if (!nullToAbsent || companyId != null) {
      map['CompanyID'] = Variable<int>(companyId);
    }
    if (!nullToAbsent || wName != null) {
      map['WName'] = Variable<String>(wName);
    }
    if (!nullToAbsent || msgNo != null) {
      map['msgno'] = Variable<String>(msgNo);
    }
    if (!nullToAbsent || hwls1 != null) {
      map['hwls1'] = Variable<String>(hwls1);
    }
    if (!nullToAbsent || hwls != null) {
      map['hwls'] = Variable<String>(hwls);
    }
    if (!nullToAbsent || advanceMess != null) {
      map['advancemess'] = Variable<String>(advanceMess);
    }
    if (!nullToAbsent || cbal != null) {
      map['cbal'] = Variable<int>(cbal);
    }
    if (!nullToAbsent || cbal1 != null) {
      map['cbal1'] = Variable<int>(cbal1);
    }
    if (!nullToAbsent || tTime != null) {
      map['TTIME'] = Variable<String>(tTime);
    }
    if (!nullToAbsent || pd != null) {
      map['PD'] = Variable<String>(pd);
    }
    if (!nullToAbsent || msgNo2 != null) {
      map['msgno2'] = Variable<String>(msgNo2);
    }
    if (!nullToAbsent || others != null) {
      map['OTHERS'] = Variable<String>(others);
    }
    if (!nullToAbsent || isSynced != null) {
      map['IsSynced'] = Variable<int>(isSynced);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['UpdatedAt'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || isDeleted != null) {
      map['IsDeleted'] = Variable<int>(isDeleted);
    }
    return map;
  }

  TransactionsPCompanion toCompanion(bool nullToAbsent) {
    return TransactionsPCompanion(
      voucherNo: voucherNo == null && nullToAbsent
          ? const Value.absent()
          : Value(voucherNo),
      tDate: tDate == null && nullToAbsent
          ? const Value.absent()
          : Value(tDate),
      accId: accId == null && nullToAbsent
          ? const Value.absent()
          : Value(accId),
      accTypeId: accTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      dr: dr == null && nullToAbsent ? const Value.absent() : Value(dr),
      cr: cr == null && nullToAbsent ? const Value.absent() : Value(cr),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      st: st == null && nullToAbsent ? const Value.absent() : Value(st),
      updateStatus: updateStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(updateStatus),
      currencyStatus: currencyStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyStatus),
      cashStatus: cashStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(cashStatus),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      wName: wName == null && nullToAbsent
          ? const Value.absent()
          : Value(wName),
      msgNo: msgNo == null && nullToAbsent
          ? const Value.absent()
          : Value(msgNo),
      hwls1: hwls1 == null && nullToAbsent
          ? const Value.absent()
          : Value(hwls1),
      hwls: hwls == null && nullToAbsent ? const Value.absent() : Value(hwls),
      advanceMess: advanceMess == null && nullToAbsent
          ? const Value.absent()
          : Value(advanceMess),
      cbal: cbal == null && nullToAbsent ? const Value.absent() : Value(cbal),
      cbal1: cbal1 == null && nullToAbsent
          ? const Value.absent()
          : Value(cbal1),
      tTime: tTime == null && nullToAbsent
          ? const Value.absent()
          : Value(tTime),
      pd: pd == null && nullToAbsent ? const Value.absent() : Value(pd),
      msgNo2: msgNo2 == null && nullToAbsent
          ? const Value.absent()
          : Value(msgNo2),
      others: others == null && nullToAbsent
          ? const Value.absent()
          : Value(others),
      isSynced: isSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(isSynced),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isDeleted: isDeleted == null && nullToAbsent
          ? const Value.absent()
          : Value(isDeleted),
    );
  }

  factory TransactionsPData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionsPData(
      voucherNo: serializer.fromJson<double?>(json['voucherNo']),
      tDate: serializer.fromJson<String?>(json['tDate']),
      accId: serializer.fromJson<int?>(json['accId']),
      accTypeId: serializer.fromJson<int?>(json['accTypeId']),
      description: serializer.fromJson<String?>(json['description']),
      dr: serializer.fromJson<double?>(json['dr']),
      cr: serializer.fromJson<double?>(json['cr']),
      status: serializer.fromJson<String?>(json['status']),
      st: serializer.fromJson<String?>(json['st']),
      updateStatus: serializer.fromJson<String?>(json['updateStatus']),
      currencyStatus: serializer.fromJson<String?>(json['currencyStatus']),
      cashStatus: serializer.fromJson<String?>(json['cashStatus']),
      userId: serializer.fromJson<int?>(json['userId']),
      companyId: serializer.fromJson<int?>(json['companyId']),
      wName: serializer.fromJson<String?>(json['wName']),
      msgNo: serializer.fromJson<String?>(json['msgNo']),
      hwls1: serializer.fromJson<String?>(json['hwls1']),
      hwls: serializer.fromJson<String?>(json['hwls']),
      advanceMess: serializer.fromJson<String?>(json['advanceMess']),
      cbal: serializer.fromJson<int?>(json['cbal']),
      cbal1: serializer.fromJson<int?>(json['cbal1']),
      tTime: serializer.fromJson<String?>(json['tTime']),
      pd: serializer.fromJson<String?>(json['pd']),
      msgNo2: serializer.fromJson<String?>(json['msgNo2']),
      others: serializer.fromJson<String?>(json['others']),
      isSynced: serializer.fromJson<int?>(json['isSynced']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      isDeleted: serializer.fromJson<int?>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'voucherNo': serializer.toJson<double?>(voucherNo),
      'tDate': serializer.toJson<String?>(tDate),
      'accId': serializer.toJson<int?>(accId),
      'accTypeId': serializer.toJson<int?>(accTypeId),
      'description': serializer.toJson<String?>(description),
      'dr': serializer.toJson<double?>(dr),
      'cr': serializer.toJson<double?>(cr),
      'status': serializer.toJson<String?>(status),
      'st': serializer.toJson<String?>(st),
      'updateStatus': serializer.toJson<String?>(updateStatus),
      'currencyStatus': serializer.toJson<String?>(currencyStatus),
      'cashStatus': serializer.toJson<String?>(cashStatus),
      'userId': serializer.toJson<int?>(userId),
      'companyId': serializer.toJson<int?>(companyId),
      'wName': serializer.toJson<String?>(wName),
      'msgNo': serializer.toJson<String?>(msgNo),
      'hwls1': serializer.toJson<String?>(hwls1),
      'hwls': serializer.toJson<String?>(hwls),
      'advanceMess': serializer.toJson<String?>(advanceMess),
      'cbal': serializer.toJson<int?>(cbal),
      'cbal1': serializer.toJson<int?>(cbal1),
      'tTime': serializer.toJson<String?>(tTime),
      'pd': serializer.toJson<String?>(pd),
      'msgNo2': serializer.toJson<String?>(msgNo2),
      'others': serializer.toJson<String?>(others),
      'isSynced': serializer.toJson<int?>(isSynced),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'isDeleted': serializer.toJson<int?>(isDeleted),
    };
  }

  TransactionsPData copyWith({
    Value<double?> voucherNo = const Value.absent(),
    Value<String?> tDate = const Value.absent(),
    Value<int?> accId = const Value.absent(),
    Value<int?> accTypeId = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<double?> dr = const Value.absent(),
    Value<double?> cr = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> st = const Value.absent(),
    Value<String?> updateStatus = const Value.absent(),
    Value<String?> currencyStatus = const Value.absent(),
    Value<String?> cashStatus = const Value.absent(),
    Value<int?> userId = const Value.absent(),
    Value<int?> companyId = const Value.absent(),
    Value<String?> wName = const Value.absent(),
    Value<String?> msgNo = const Value.absent(),
    Value<String?> hwls1 = const Value.absent(),
    Value<String?> hwls = const Value.absent(),
    Value<String?> advanceMess = const Value.absent(),
    Value<int?> cbal = const Value.absent(),
    Value<int?> cbal1 = const Value.absent(),
    Value<String?> tTime = const Value.absent(),
    Value<String?> pd = const Value.absent(),
    Value<String?> msgNo2 = const Value.absent(),
    Value<String?> others = const Value.absent(),
    Value<int?> isSynced = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<int?> isDeleted = const Value.absent(),
  }) => TransactionsPData(
    voucherNo: voucherNo.present ? voucherNo.value : this.voucherNo,
    tDate: tDate.present ? tDate.value : this.tDate,
    accId: accId.present ? accId.value : this.accId,
    accTypeId: accTypeId.present ? accTypeId.value : this.accTypeId,
    description: description.present ? description.value : this.description,
    dr: dr.present ? dr.value : this.dr,
    cr: cr.present ? cr.value : this.cr,
    status: status.present ? status.value : this.status,
    st: st.present ? st.value : this.st,
    updateStatus: updateStatus.present ? updateStatus.value : this.updateStatus,
    currencyStatus: currencyStatus.present
        ? currencyStatus.value
        : this.currencyStatus,
    cashStatus: cashStatus.present ? cashStatus.value : this.cashStatus,
    userId: userId.present ? userId.value : this.userId,
    companyId: companyId.present ? companyId.value : this.companyId,
    wName: wName.present ? wName.value : this.wName,
    msgNo: msgNo.present ? msgNo.value : this.msgNo,
    hwls1: hwls1.present ? hwls1.value : this.hwls1,
    hwls: hwls.present ? hwls.value : this.hwls,
    advanceMess: advanceMess.present ? advanceMess.value : this.advanceMess,
    cbal: cbal.present ? cbal.value : this.cbal,
    cbal1: cbal1.present ? cbal1.value : this.cbal1,
    tTime: tTime.present ? tTime.value : this.tTime,
    pd: pd.present ? pd.value : this.pd,
    msgNo2: msgNo2.present ? msgNo2.value : this.msgNo2,
    others: others.present ? others.value : this.others,
    isSynced: isSynced.present ? isSynced.value : this.isSynced,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    isDeleted: isDeleted.present ? isDeleted.value : this.isDeleted,
  );
  TransactionsPData copyWithCompanion(TransactionsPCompanion data) {
    return TransactionsPData(
      voucherNo: data.voucherNo.present ? data.voucherNo.value : this.voucherNo,
      tDate: data.tDate.present ? data.tDate.value : this.tDate,
      accId: data.accId.present ? data.accId.value : this.accId,
      accTypeId: data.accTypeId.present ? data.accTypeId.value : this.accTypeId,
      description: data.description.present
          ? data.description.value
          : this.description,
      dr: data.dr.present ? data.dr.value : this.dr,
      cr: data.cr.present ? data.cr.value : this.cr,
      status: data.status.present ? data.status.value : this.status,
      st: data.st.present ? data.st.value : this.st,
      updateStatus: data.updateStatus.present
          ? data.updateStatus.value
          : this.updateStatus,
      currencyStatus: data.currencyStatus.present
          ? data.currencyStatus.value
          : this.currencyStatus,
      cashStatus: data.cashStatus.present
          ? data.cashStatus.value
          : this.cashStatus,
      userId: data.userId.present ? data.userId.value : this.userId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      wName: data.wName.present ? data.wName.value : this.wName,
      msgNo: data.msgNo.present ? data.msgNo.value : this.msgNo,
      hwls1: data.hwls1.present ? data.hwls1.value : this.hwls1,
      hwls: data.hwls.present ? data.hwls.value : this.hwls,
      advanceMess: data.advanceMess.present
          ? data.advanceMess.value
          : this.advanceMess,
      cbal: data.cbal.present ? data.cbal.value : this.cbal,
      cbal1: data.cbal1.present ? data.cbal1.value : this.cbal1,
      tTime: data.tTime.present ? data.tTime.value : this.tTime,
      pd: data.pd.present ? data.pd.value : this.pd,
      msgNo2: data.msgNo2.present ? data.msgNo2.value : this.msgNo2,
      others: data.others.present ? data.others.value : this.others,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsPData(')
          ..write('voucherNo: $voucherNo, ')
          ..write('tDate: $tDate, ')
          ..write('accId: $accId, ')
          ..write('accTypeId: $accTypeId, ')
          ..write('description: $description, ')
          ..write('dr: $dr, ')
          ..write('cr: $cr, ')
          ..write('status: $status, ')
          ..write('st: $st, ')
          ..write('updateStatus: $updateStatus, ')
          ..write('currencyStatus: $currencyStatus, ')
          ..write('cashStatus: $cashStatus, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName, ')
          ..write('msgNo: $msgNo, ')
          ..write('hwls1: $hwls1, ')
          ..write('hwls: $hwls, ')
          ..write('advanceMess: $advanceMess, ')
          ..write('cbal: $cbal, ')
          ..write('cbal1: $cbal1, ')
          ..write('tTime: $tTime, ')
          ..write('pd: $pd, ')
          ..write('msgNo2: $msgNo2, ')
          ..write('others: $others, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    voucherNo,
    tDate,
    accId,
    accTypeId,
    description,
    dr,
    cr,
    status,
    st,
    updateStatus,
    currencyStatus,
    cashStatus,
    userId,
    companyId,
    wName,
    msgNo,
    hwls1,
    hwls,
    advanceMess,
    cbal,
    cbal1,
    tTime,
    pd,
    msgNo2,
    others,
    isSynced,
    updatedAt,
    isDeleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionsPData &&
          other.voucherNo == this.voucherNo &&
          other.tDate == this.tDate &&
          other.accId == this.accId &&
          other.accTypeId == this.accTypeId &&
          other.description == this.description &&
          other.dr == this.dr &&
          other.cr == this.cr &&
          other.status == this.status &&
          other.st == this.st &&
          other.updateStatus == this.updateStatus &&
          other.currencyStatus == this.currencyStatus &&
          other.cashStatus == this.cashStatus &&
          other.userId == this.userId &&
          other.companyId == this.companyId &&
          other.wName == this.wName &&
          other.msgNo == this.msgNo &&
          other.hwls1 == this.hwls1 &&
          other.hwls == this.hwls &&
          other.advanceMess == this.advanceMess &&
          other.cbal == this.cbal &&
          other.cbal1 == this.cbal1 &&
          other.tTime == this.tTime &&
          other.pd == this.pd &&
          other.msgNo2 == this.msgNo2 &&
          other.others == this.others &&
          other.isSynced == this.isSynced &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class TransactionsPCompanion extends UpdateCompanion<TransactionsPData> {
  final Value<double?> voucherNo;
  final Value<String?> tDate;
  final Value<int?> accId;
  final Value<int?> accTypeId;
  final Value<String?> description;
  final Value<double?> dr;
  final Value<double?> cr;
  final Value<String?> status;
  final Value<String?> st;
  final Value<String?> updateStatus;
  final Value<String?> currencyStatus;
  final Value<String?> cashStatus;
  final Value<int?> userId;
  final Value<int?> companyId;
  final Value<String?> wName;
  final Value<String?> msgNo;
  final Value<String?> hwls1;
  final Value<String?> hwls;
  final Value<String?> advanceMess;
  final Value<int?> cbal;
  final Value<int?> cbal1;
  final Value<String?> tTime;
  final Value<String?> pd;
  final Value<String?> msgNo2;
  final Value<String?> others;
  final Value<int?> isSynced;
  final Value<String?> updatedAt;
  final Value<int?> isDeleted;
  final Value<int> rowid;
  const TransactionsPCompanion({
    this.voucherNo = const Value.absent(),
    this.tDate = const Value.absent(),
    this.accId = const Value.absent(),
    this.accTypeId = const Value.absent(),
    this.description = const Value.absent(),
    this.dr = const Value.absent(),
    this.cr = const Value.absent(),
    this.status = const Value.absent(),
    this.st = const Value.absent(),
    this.updateStatus = const Value.absent(),
    this.currencyStatus = const Value.absent(),
    this.cashStatus = const Value.absent(),
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
    this.msgNo = const Value.absent(),
    this.hwls1 = const Value.absent(),
    this.hwls = const Value.absent(),
    this.advanceMess = const Value.absent(),
    this.cbal = const Value.absent(),
    this.cbal1 = const Value.absent(),
    this.tTime = const Value.absent(),
    this.pd = const Value.absent(),
    this.msgNo2 = const Value.absent(),
    this.others = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsPCompanion.insert({
    this.voucherNo = const Value.absent(),
    this.tDate = const Value.absent(),
    this.accId = const Value.absent(),
    this.accTypeId = const Value.absent(),
    this.description = const Value.absent(),
    this.dr = const Value.absent(),
    this.cr = const Value.absent(),
    this.status = const Value.absent(),
    this.st = const Value.absent(),
    this.updateStatus = const Value.absent(),
    this.currencyStatus = const Value.absent(),
    this.cashStatus = const Value.absent(),
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
    this.msgNo = const Value.absent(),
    this.hwls1 = const Value.absent(),
    this.hwls = const Value.absent(),
    this.advanceMess = const Value.absent(),
    this.cbal = const Value.absent(),
    this.cbal1 = const Value.absent(),
    this.tTime = const Value.absent(),
    this.pd = const Value.absent(),
    this.msgNo2 = const Value.absent(),
    this.others = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<TransactionsPData> custom({
    Expression<double>? voucherNo,
    Expression<String>? tDate,
    Expression<int>? accId,
    Expression<int>? accTypeId,
    Expression<String>? description,
    Expression<double>? dr,
    Expression<double>? cr,
    Expression<String>? status,
    Expression<String>? st,
    Expression<String>? updateStatus,
    Expression<String>? currencyStatus,
    Expression<String>? cashStatus,
    Expression<int>? userId,
    Expression<int>? companyId,
    Expression<String>? wName,
    Expression<String>? msgNo,
    Expression<String>? hwls1,
    Expression<String>? hwls,
    Expression<String>? advanceMess,
    Expression<int>? cbal,
    Expression<int>? cbal1,
    Expression<String>? tTime,
    Expression<String>? pd,
    Expression<String>? msgNo2,
    Expression<String>? others,
    Expression<int>? isSynced,
    Expression<String>? updatedAt,
    Expression<int>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (voucherNo != null) 'VoucherNo': voucherNo,
      if (tDate != null) 'TDate': tDate,
      if (accId != null) 'AccID': accId,
      if (accTypeId != null) 'AccTypeID': accTypeId,
      if (description != null) 'Description': description,
      if (dr != null) 'Dr': dr,
      if (cr != null) 'Cr': cr,
      if (status != null) 'Status': status,
      if (st != null) 'st': st,
      if (updateStatus != null) 'updatestatus': updateStatus,
      if (currencyStatus != null) 'currencystatus': currencyStatus,
      if (cashStatus != null) 'cashstatus': cashStatus,
      if (userId != null) 'UserID': userId,
      if (companyId != null) 'CompanyID': companyId,
      if (wName != null) 'WName': wName,
      if (msgNo != null) 'msgno': msgNo,
      if (hwls1 != null) 'hwls1': hwls1,
      if (hwls != null) 'hwls': hwls,
      if (advanceMess != null) 'advancemess': advanceMess,
      if (cbal != null) 'cbal': cbal,
      if (cbal1 != null) 'cbal1': cbal1,
      if (tTime != null) 'TTIME': tTime,
      if (pd != null) 'PD': pd,
      if (msgNo2 != null) 'msgno2': msgNo2,
      if (others != null) 'OTHERS': others,
      if (isSynced != null) 'IsSynced': isSynced,
      if (updatedAt != null) 'UpdatedAt': updatedAt,
      if (isDeleted != null) 'IsDeleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsPCompanion copyWith({
    Value<double?>? voucherNo,
    Value<String?>? tDate,
    Value<int?>? accId,
    Value<int?>? accTypeId,
    Value<String?>? description,
    Value<double?>? dr,
    Value<double?>? cr,
    Value<String?>? status,
    Value<String?>? st,
    Value<String?>? updateStatus,
    Value<String?>? currencyStatus,
    Value<String?>? cashStatus,
    Value<int?>? userId,
    Value<int?>? companyId,
    Value<String?>? wName,
    Value<String?>? msgNo,
    Value<String?>? hwls1,
    Value<String?>? hwls,
    Value<String?>? advanceMess,
    Value<int?>? cbal,
    Value<int?>? cbal1,
    Value<String?>? tTime,
    Value<String?>? pd,
    Value<String?>? msgNo2,
    Value<String?>? others,
    Value<int?>? isSynced,
    Value<String?>? updatedAt,
    Value<int?>? isDeleted,
    Value<int>? rowid,
  }) {
    return TransactionsPCompanion(
      voucherNo: voucherNo ?? this.voucherNo,
      tDate: tDate ?? this.tDate,
      accId: accId ?? this.accId,
      accTypeId: accTypeId ?? this.accTypeId,
      description: description ?? this.description,
      dr: dr ?? this.dr,
      cr: cr ?? this.cr,
      status: status ?? this.status,
      st: st ?? this.st,
      updateStatus: updateStatus ?? this.updateStatus,
      currencyStatus: currencyStatus ?? this.currencyStatus,
      cashStatus: cashStatus ?? this.cashStatus,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      wName: wName ?? this.wName,
      msgNo: msgNo ?? this.msgNo,
      hwls1: hwls1 ?? this.hwls1,
      hwls: hwls ?? this.hwls,
      advanceMess: advanceMess ?? this.advanceMess,
      cbal: cbal ?? this.cbal,
      cbal1: cbal1 ?? this.cbal1,
      tTime: tTime ?? this.tTime,
      pd: pd ?? this.pd,
      msgNo2: msgNo2 ?? this.msgNo2,
      others: others ?? this.others,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (voucherNo.present) {
      map['VoucherNo'] = Variable<double>(voucherNo.value);
    }
    if (tDate.present) {
      map['TDate'] = Variable<String>(tDate.value);
    }
    if (accId.present) {
      map['AccID'] = Variable<int>(accId.value);
    }
    if (accTypeId.present) {
      map['AccTypeID'] = Variable<int>(accTypeId.value);
    }
    if (description.present) {
      map['Description'] = Variable<String>(description.value);
    }
    if (dr.present) {
      map['Dr'] = Variable<double>(dr.value);
    }
    if (cr.present) {
      map['Cr'] = Variable<double>(cr.value);
    }
    if (status.present) {
      map['Status'] = Variable<String>(status.value);
    }
    if (st.present) {
      map['st'] = Variable<String>(st.value);
    }
    if (updateStatus.present) {
      map['updatestatus'] = Variable<String>(updateStatus.value);
    }
    if (currencyStatus.present) {
      map['currencystatus'] = Variable<String>(currencyStatus.value);
    }
    if (cashStatus.present) {
      map['cashstatus'] = Variable<String>(cashStatus.value);
    }
    if (userId.present) {
      map['UserID'] = Variable<int>(userId.value);
    }
    if (companyId.present) {
      map['CompanyID'] = Variable<int>(companyId.value);
    }
    if (wName.present) {
      map['WName'] = Variable<String>(wName.value);
    }
    if (msgNo.present) {
      map['msgno'] = Variable<String>(msgNo.value);
    }
    if (hwls1.present) {
      map['hwls1'] = Variable<String>(hwls1.value);
    }
    if (hwls.present) {
      map['hwls'] = Variable<String>(hwls.value);
    }
    if (advanceMess.present) {
      map['advancemess'] = Variable<String>(advanceMess.value);
    }
    if (cbal.present) {
      map['cbal'] = Variable<int>(cbal.value);
    }
    if (cbal1.present) {
      map['cbal1'] = Variable<int>(cbal1.value);
    }
    if (tTime.present) {
      map['TTIME'] = Variable<String>(tTime.value);
    }
    if (pd.present) {
      map['PD'] = Variable<String>(pd.value);
    }
    if (msgNo2.present) {
      map['msgno2'] = Variable<String>(msgNo2.value);
    }
    if (others.present) {
      map['OTHERS'] = Variable<String>(others.value);
    }
    if (isSynced.present) {
      map['IsSynced'] = Variable<int>(isSynced.value);
    }
    if (updatedAt.present) {
      map['UpdatedAt'] = Variable<String>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['IsDeleted'] = Variable<int>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsPCompanion(')
          ..write('voucherNo: $voucherNo, ')
          ..write('tDate: $tDate, ')
          ..write('accId: $accId, ')
          ..write('accTypeId: $accTypeId, ')
          ..write('description: $description, ')
          ..write('dr: $dr, ')
          ..write('cr: $cr, ')
          ..write('status: $status, ')
          ..write('st: $st, ')
          ..write('updateStatus: $updateStatus, ')
          ..write('currencyStatus: $currencyStatus, ')
          ..write('cashStatus: $cashStatus, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName, ')
          ..write('msgNo: $msgNo, ')
          ..write('hwls1: $hwls1, ')
          ..write('hwls: $hwls, ')
          ..write('advanceMess: $advanceMess, ')
          ..write('cbal: $cbal, ')
          ..write('cbal1: $cbal1, ')
          ..write('tTime: $tTime, ')
          ..write('pd: $pd, ')
          ..write('msgNo2: $msgNo2, ')
          ..write('others: $others, ')
          ..write('isSynced: $isSynced, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccPersonalTable accPersonal = $AccPersonalTable(this);
  late final $AccTypeTable accType = $AccTypeTable(this);
  late final $CompanyTableTable companyTable = $CompanyTableTable(this);
  late final $DbInfoTableTable dbInfoTable = $DbInfoTableTable(this);
  late final $TransactionsPTable transactionsP = $TransactionsPTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accPersonal,
    accType,
    companyTable,
    dbInfoTable,
    transactionsP,
  ];
}

typedef $$AccPersonalTableCreateCompanionBuilder =
    AccPersonalCompanion Function({
      Value<int> accId,
      Value<String?> rDate,
      Value<String?> name,
      Value<String?> phone,
      Value<String?> fax,
      Value<String?> address,
      Value<String?> description,
      Value<String?> uAccName,
      Value<String?> statusg,
      Value<int?> userId,
      Value<int?> companyId,
      Value<String?> wName,
      Value<int?> isSynced,
      Value<String?> updatedAt,
      Value<int?> isDeleted,
    });
typedef $$AccPersonalTableUpdateCompanionBuilder =
    AccPersonalCompanion Function({
      Value<int> accId,
      Value<String?> rDate,
      Value<String?> name,
      Value<String?> phone,
      Value<String?> fax,
      Value<String?> address,
      Value<String?> description,
      Value<String?> uAccName,
      Value<String?> statusg,
      Value<int?> userId,
      Value<int?> companyId,
      Value<String?> wName,
      Value<int?> isSynced,
      Value<String?> updatedAt,
      Value<int?> isDeleted,
    });

class $$AccPersonalTableFilterComposer
    extends Composer<_$AppDatabase, $AccPersonalTable> {
  $$AccPersonalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get accId => $composableBuilder(
    column: $table.accId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rDate => $composableBuilder(
    column: $table.rDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fax => $composableBuilder(
    column: $table.fax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uAccName => $composableBuilder(
    column: $table.uAccName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusg => $composableBuilder(
    column: $table.statusg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wName => $composableBuilder(
    column: $table.wName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccPersonalTableOrderingComposer
    extends Composer<_$AppDatabase, $AccPersonalTable> {
  $$AccPersonalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get accId => $composableBuilder(
    column: $table.accId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rDate => $composableBuilder(
    column: $table.rDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fax => $composableBuilder(
    column: $table.fax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uAccName => $composableBuilder(
    column: $table.uAccName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusg => $composableBuilder(
    column: $table.statusg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wName => $composableBuilder(
    column: $table.wName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccPersonalTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccPersonalTable> {
  $$AccPersonalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get accId =>
      $composableBuilder(column: $table.accId, builder: (column) => column);

  GeneratedColumn<String> get rDate =>
      $composableBuilder(column: $table.rDate, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get fax =>
      $composableBuilder(column: $table.fax, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uAccName =>
      $composableBuilder(column: $table.uAccName, builder: (column) => column);

  GeneratedColumn<String> get statusg =>
      $composableBuilder(column: $table.statusg, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get wName =>
      $composableBuilder(column: $table.wName, builder: (column) => column);

  GeneratedColumn<int> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$AccPersonalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccPersonalTable,
          AccPersonalData,
          $$AccPersonalTableFilterComposer,
          $$AccPersonalTableOrderingComposer,
          $$AccPersonalTableAnnotationComposer,
          $$AccPersonalTableCreateCompanionBuilder,
          $$AccPersonalTableUpdateCompanionBuilder,
          (
            AccPersonalData,
            BaseReferences<_$AppDatabase, $AccPersonalTable, AccPersonalData>,
          ),
          AccPersonalData,
          PrefetchHooks Function()
        > {
  $$AccPersonalTableTableManager(_$AppDatabase db, $AccPersonalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccPersonalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccPersonalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccPersonalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> accId = const Value.absent(),
                Value<String?> rDate = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> fax = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> uAccName = const Value.absent(),
                Value<String?> statusg = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> isDeleted = const Value.absent(),
              }) => AccPersonalCompanion(
                accId: accId,
                rDate: rDate,
                name: name,
                phone: phone,
                fax: fax,
                address: address,
                description: description,
                uAccName: uAccName,
                statusg: statusg,
                userId: userId,
                companyId: companyId,
                wName: wName,
                isSynced: isSynced,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> accId = const Value.absent(),
                Value<String?> rDate = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> fax = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> uAccName = const Value.absent(),
                Value<String?> statusg = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> isDeleted = const Value.absent(),
              }) => AccPersonalCompanion.insert(
                accId: accId,
                rDate: rDate,
                name: name,
                phone: phone,
                fax: fax,
                address: address,
                description: description,
                uAccName: uAccName,
                statusg: statusg,
                userId: userId,
                companyId: companyId,
                wName: wName,
                isSynced: isSynced,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccPersonalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccPersonalTable,
      AccPersonalData,
      $$AccPersonalTableFilterComposer,
      $$AccPersonalTableOrderingComposer,
      $$AccPersonalTableAnnotationComposer,
      $$AccPersonalTableCreateCompanionBuilder,
      $$AccPersonalTableUpdateCompanionBuilder,
      (
        AccPersonalData,
        BaseReferences<_$AppDatabase, $AccPersonalTable, AccPersonalData>,
      ),
      AccPersonalData,
      PrefetchHooks Function()
    >;
typedef $$AccTypeTableCreateCompanionBuilder =
    AccTypeCompanion Function({
      Value<int> accTypeId,
      Value<String?> accTypeName,
      Value<String?> accTypeNameU,
      Value<String?> flag,
      Value<int?> isSynced,
      Value<String?> updatedAt,
    });
typedef $$AccTypeTableUpdateCompanionBuilder =
    AccTypeCompanion Function({
      Value<int> accTypeId,
      Value<String?> accTypeName,
      Value<String?> accTypeNameU,
      Value<String?> flag,
      Value<int?> isSynced,
      Value<String?> updatedAt,
    });

class $$AccTypeTableFilterComposer
    extends Composer<_$AppDatabase, $AccTypeTable> {
  $$AccTypeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accTypeName => $composableBuilder(
    column: $table.accTypeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accTypeNameU => $composableBuilder(
    column: $table.accTypeNameU,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccTypeTableOrderingComposer
    extends Composer<_$AppDatabase, $AccTypeTable> {
  $$AccTypeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accTypeName => $composableBuilder(
    column: $table.accTypeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accTypeNameU => $composableBuilder(
    column: $table.accTypeNameU,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccTypeTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccTypeTable> {
  $$AccTypeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get accTypeId =>
      $composableBuilder(column: $table.accTypeId, builder: (column) => column);

  GeneratedColumn<String> get accTypeName => $composableBuilder(
    column: $table.accTypeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accTypeNameU => $composableBuilder(
    column: $table.accTypeNameU,
    builder: (column) => column,
  );

  GeneratedColumn<String> get flag =>
      $composableBuilder(column: $table.flag, builder: (column) => column);

  GeneratedColumn<int> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AccTypeTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccTypeTable,
          AccTypeData,
          $$AccTypeTableFilterComposer,
          $$AccTypeTableOrderingComposer,
          $$AccTypeTableAnnotationComposer,
          $$AccTypeTableCreateCompanionBuilder,
          $$AccTypeTableUpdateCompanionBuilder,
          (
            AccTypeData,
            BaseReferences<_$AppDatabase, $AccTypeTable, AccTypeData>,
          ),
          AccTypeData,
          PrefetchHooks Function()
        > {
  $$AccTypeTableTableManager(_$AppDatabase db, $AccTypeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccTypeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccTypeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccTypeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> accTypeId = const Value.absent(),
                Value<String?> accTypeName = const Value.absent(),
                Value<String?> accTypeNameU = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => AccTypeCompanion(
                accTypeId: accTypeId,
                accTypeName: accTypeName,
                accTypeNameU: accTypeNameU,
                flag: flag,
                isSynced: isSynced,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> accTypeId = const Value.absent(),
                Value<String?> accTypeName = const Value.absent(),
                Value<String?> accTypeNameU = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => AccTypeCompanion.insert(
                accTypeId: accTypeId,
                accTypeName: accTypeName,
                accTypeNameU: accTypeNameU,
                flag: flag,
                isSynced: isSynced,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccTypeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccTypeTable,
      AccTypeData,
      $$AccTypeTableFilterComposer,
      $$AccTypeTableOrderingComposer,
      $$AccTypeTableAnnotationComposer,
      $$AccTypeTableCreateCompanionBuilder,
      $$AccTypeTableUpdateCompanionBuilder,
      (AccTypeData, BaseReferences<_$AppDatabase, $AccTypeTable, AccTypeData>),
      AccTypeData,
      PrefetchHooks Function()
    >;
typedef $$CompanyTableTableCreateCompanionBuilder =
    CompanyTableCompanion Function({
      Value<int> companyId,
      Value<String?> companyName,
      Value<String?> remarks,
    });
typedef $$CompanyTableTableUpdateCompanionBuilder =
    CompanyTableCompanion Function({
      Value<int> companyId,
      Value<String?> companyName,
      Value<String?> remarks,
    });

class $$CompanyTableTableFilterComposer
    extends Composer<_$AppDatabase, $CompanyTableTable> {
  $$CompanyTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompanyTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CompanyTableTable> {
  $$CompanyTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompanyTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompanyTableTable> {
  $$CompanyTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);
}

class $$CompanyTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompanyTableTable,
          CompanyTableData,
          $$CompanyTableTableFilterComposer,
          $$CompanyTableTableOrderingComposer,
          $$CompanyTableTableAnnotationComposer,
          $$CompanyTableTableCreateCompanionBuilder,
          $$CompanyTableTableUpdateCompanionBuilder,
          (
            CompanyTableData,
            BaseReferences<_$AppDatabase, $CompanyTableTable, CompanyTableData>,
          ),
          CompanyTableData,
          PrefetchHooks Function()
        > {
  $$CompanyTableTableTableManager(_$AppDatabase db, $CompanyTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompanyTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompanyTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompanyTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> companyId = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
              }) => CompanyTableCompanion(
                companyId: companyId,
                companyName: companyName,
                remarks: remarks,
              ),
          createCompanionCallback:
              ({
                Value<int> companyId = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
              }) => CompanyTableCompanion.insert(
                companyId: companyId,
                companyName: companyName,
                remarks: remarks,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompanyTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompanyTableTable,
      CompanyTableData,
      $$CompanyTableTableFilterComposer,
      $$CompanyTableTableOrderingComposer,
      $$CompanyTableTableAnnotationComposer,
      $$CompanyTableTableCreateCompanionBuilder,
      $$CompanyTableTableUpdateCompanionBuilder,
      (
        CompanyTableData,
        BaseReferences<_$AppDatabase, $CompanyTableTable, CompanyTableData>,
      ),
      CompanyTableData,
      PrefetchHooks Function()
    >;
typedef $$DbInfoTableTableCreateCompanionBuilder =
    DbInfoTableCompanion Function({
      Value<String?> emailAddress,
      Value<String?> databaseName,
      Value<int> rowid,
    });
typedef $$DbInfoTableTableUpdateCompanionBuilder =
    DbInfoTableCompanion Function({
      Value<String?> emailAddress,
      Value<String?> databaseName,
      Value<int> rowid,
    });

class $$DbInfoTableTableFilterComposer
    extends Composer<_$AppDatabase, $DbInfoTableTable> {
  $$DbInfoTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbInfoTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DbInfoTableTable> {
  $$DbInfoTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbInfoTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbInfoTableTable> {
  $$DbInfoTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get emailAddress => $composableBuilder(
    column: $table.emailAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => column,
  );
}

class $$DbInfoTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbInfoTableTable,
          DbInfoTableData,
          $$DbInfoTableTableFilterComposer,
          $$DbInfoTableTableOrderingComposer,
          $$DbInfoTableTableAnnotationComposer,
          $$DbInfoTableTableCreateCompanionBuilder,
          $$DbInfoTableTableUpdateCompanionBuilder,
          (
            DbInfoTableData,
            BaseReferences<_$AppDatabase, $DbInfoTableTable, DbInfoTableData>,
          ),
          DbInfoTableData,
          PrefetchHooks Function()
        > {
  $$DbInfoTableTableTableManager(_$AppDatabase db, $DbInfoTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbInfoTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbInfoTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbInfoTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> emailAddress = const Value.absent(),
                Value<String?> databaseName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbInfoTableCompanion(
                emailAddress: emailAddress,
                databaseName: databaseName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> emailAddress = const Value.absent(),
                Value<String?> databaseName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbInfoTableCompanion.insert(
                emailAddress: emailAddress,
                databaseName: databaseName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbInfoTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbInfoTableTable,
      DbInfoTableData,
      $$DbInfoTableTableFilterComposer,
      $$DbInfoTableTableOrderingComposer,
      $$DbInfoTableTableAnnotationComposer,
      $$DbInfoTableTableCreateCompanionBuilder,
      $$DbInfoTableTableUpdateCompanionBuilder,
      (
        DbInfoTableData,
        BaseReferences<_$AppDatabase, $DbInfoTableTable, DbInfoTableData>,
      ),
      DbInfoTableData,
      PrefetchHooks Function()
    >;
typedef $$TransactionsPTableCreateCompanionBuilder =
    TransactionsPCompanion Function({
      Value<double?> voucherNo,
      Value<String?> tDate,
      Value<int?> accId,
      Value<int?> accTypeId,
      Value<String?> description,
      Value<double?> dr,
      Value<double?> cr,
      Value<String?> status,
      Value<String?> st,
      Value<String?> updateStatus,
      Value<String?> currencyStatus,
      Value<String?> cashStatus,
      Value<int?> userId,
      Value<int?> companyId,
      Value<String?> wName,
      Value<String?> msgNo,
      Value<String?> hwls1,
      Value<String?> hwls,
      Value<String?> advanceMess,
      Value<int?> cbal,
      Value<int?> cbal1,
      Value<String?> tTime,
      Value<String?> pd,
      Value<String?> msgNo2,
      Value<String?> others,
      Value<int?> isSynced,
      Value<String?> updatedAt,
      Value<int?> isDeleted,
      Value<int> rowid,
    });
typedef $$TransactionsPTableUpdateCompanionBuilder =
    TransactionsPCompanion Function({
      Value<double?> voucherNo,
      Value<String?> tDate,
      Value<int?> accId,
      Value<int?> accTypeId,
      Value<String?> description,
      Value<double?> dr,
      Value<double?> cr,
      Value<String?> status,
      Value<String?> st,
      Value<String?> updateStatus,
      Value<String?> currencyStatus,
      Value<String?> cashStatus,
      Value<int?> userId,
      Value<int?> companyId,
      Value<String?> wName,
      Value<String?> msgNo,
      Value<String?> hwls1,
      Value<String?> hwls,
      Value<String?> advanceMess,
      Value<int?> cbal,
      Value<int?> cbal1,
      Value<String?> tTime,
      Value<String?> pd,
      Value<String?> msgNo2,
      Value<String?> others,
      Value<int?> isSynced,
      Value<String?> updatedAt,
      Value<int?> isDeleted,
      Value<int> rowid,
    });

class $$TransactionsPTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsPTable> {
  $$TransactionsPTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get voucherNo => $composableBuilder(
    column: $table.voucherNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tDate => $composableBuilder(
    column: $table.tDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accId => $composableBuilder(
    column: $table.accId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dr => $composableBuilder(
    column: $table.dr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cr => $composableBuilder(
    column: $table.cr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get st => $composableBuilder(
    column: $table.st,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateStatus => $composableBuilder(
    column: $table.updateStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashStatus => $composableBuilder(
    column: $table.cashStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wName => $composableBuilder(
    column: $table.wName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get msgNo => $composableBuilder(
    column: $table.msgNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hwls1 => $composableBuilder(
    column: $table.hwls1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hwls => $composableBuilder(
    column: $table.hwls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get advanceMess => $composableBuilder(
    column: $table.advanceMess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cbal => $composableBuilder(
    column: $table.cbal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cbal1 => $composableBuilder(
    column: $table.cbal1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tTime => $composableBuilder(
    column: $table.tTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pd => $composableBuilder(
    column: $table.pd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get msgNo2 => $composableBuilder(
    column: $table.msgNo2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get others => $composableBuilder(
    column: $table.others,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsPTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsPTable> {
  $$TransactionsPTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get voucherNo => $composableBuilder(
    column: $table.voucherNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tDate => $composableBuilder(
    column: $table.tDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accId => $composableBuilder(
    column: $table.accId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dr => $composableBuilder(
    column: $table.dr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cr => $composableBuilder(
    column: $table.cr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get st => $composableBuilder(
    column: $table.st,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateStatus => $composableBuilder(
    column: $table.updateStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashStatus => $composableBuilder(
    column: $table.cashStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wName => $composableBuilder(
    column: $table.wName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get msgNo => $composableBuilder(
    column: $table.msgNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hwls1 => $composableBuilder(
    column: $table.hwls1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hwls => $composableBuilder(
    column: $table.hwls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get advanceMess => $composableBuilder(
    column: $table.advanceMess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cbal => $composableBuilder(
    column: $table.cbal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cbal1 => $composableBuilder(
    column: $table.cbal1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tTime => $composableBuilder(
    column: $table.tTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pd => $composableBuilder(
    column: $table.pd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get msgNo2 => $composableBuilder(
    column: $table.msgNo2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get others => $composableBuilder(
    column: $table.others,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsPTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsPTable> {
  $$TransactionsPTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get voucherNo =>
      $composableBuilder(column: $table.voucherNo, builder: (column) => column);

  GeneratedColumn<String> get tDate =>
      $composableBuilder(column: $table.tDate, builder: (column) => column);

  GeneratedColumn<int> get accId =>
      $composableBuilder(column: $table.accId, builder: (column) => column);

  GeneratedColumn<int> get accTypeId =>
      $composableBuilder(column: $table.accTypeId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dr =>
      $composableBuilder(column: $table.dr, builder: (column) => column);

  GeneratedColumn<double> get cr =>
      $composableBuilder(column: $table.cr, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get st =>
      $composableBuilder(column: $table.st, builder: (column) => column);

  GeneratedColumn<String> get updateStatus => $composableBuilder(
    column: $table.updateStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cashStatus => $composableBuilder(
    column: $table.cashStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get wName =>
      $composableBuilder(column: $table.wName, builder: (column) => column);

  GeneratedColumn<String> get msgNo =>
      $composableBuilder(column: $table.msgNo, builder: (column) => column);

  GeneratedColumn<String> get hwls1 =>
      $composableBuilder(column: $table.hwls1, builder: (column) => column);

  GeneratedColumn<String> get hwls =>
      $composableBuilder(column: $table.hwls, builder: (column) => column);

  GeneratedColumn<String> get advanceMess => $composableBuilder(
    column: $table.advanceMess,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cbal =>
      $composableBuilder(column: $table.cbal, builder: (column) => column);

  GeneratedColumn<int> get cbal1 =>
      $composableBuilder(column: $table.cbal1, builder: (column) => column);

  GeneratedColumn<String> get tTime =>
      $composableBuilder(column: $table.tTime, builder: (column) => column);

  GeneratedColumn<String> get pd =>
      $composableBuilder(column: $table.pd, builder: (column) => column);

  GeneratedColumn<String> get msgNo2 =>
      $composableBuilder(column: $table.msgNo2, builder: (column) => column);

  GeneratedColumn<String> get others =>
      $composableBuilder(column: $table.others, builder: (column) => column);

  GeneratedColumn<int> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$TransactionsPTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsPTable,
          TransactionsPData,
          $$TransactionsPTableFilterComposer,
          $$TransactionsPTableOrderingComposer,
          $$TransactionsPTableAnnotationComposer,
          $$TransactionsPTableCreateCompanionBuilder,
          $$TransactionsPTableUpdateCompanionBuilder,
          (
            TransactionsPData,
            BaseReferences<
              _$AppDatabase,
              $TransactionsPTable,
              TransactionsPData
            >,
          ),
          TransactionsPData,
          PrefetchHooks Function()
        > {
  $$TransactionsPTableTableManager(_$AppDatabase db, $TransactionsPTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsPTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsPTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsPTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<double?> voucherNo = const Value.absent(),
                Value<String?> tDate = const Value.absent(),
                Value<int?> accId = const Value.absent(),
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> dr = const Value.absent(),
                Value<double?> cr = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> st = const Value.absent(),
                Value<String?> updateStatus = const Value.absent(),
                Value<String?> currencyStatus = const Value.absent(),
                Value<String?> cashStatus = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
                Value<String?> msgNo = const Value.absent(),
                Value<String?> hwls1 = const Value.absent(),
                Value<String?> hwls = const Value.absent(),
                Value<String?> advanceMess = const Value.absent(),
                Value<int?> cbal = const Value.absent(),
                Value<int?> cbal1 = const Value.absent(),
                Value<String?> tTime = const Value.absent(),
                Value<String?> pd = const Value.absent(),
                Value<String?> msgNo2 = const Value.absent(),
                Value<String?> others = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsPCompanion(
                voucherNo: voucherNo,
                tDate: tDate,
                accId: accId,
                accTypeId: accTypeId,
                description: description,
                dr: dr,
                cr: cr,
                status: status,
                st: st,
                updateStatus: updateStatus,
                currencyStatus: currencyStatus,
                cashStatus: cashStatus,
                userId: userId,
                companyId: companyId,
                wName: wName,
                msgNo: msgNo,
                hwls1: hwls1,
                hwls: hwls,
                advanceMess: advanceMess,
                cbal: cbal,
                cbal1: cbal1,
                tTime: tTime,
                pd: pd,
                msgNo2: msgNo2,
                others: others,
                isSynced: isSynced,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<double?> voucherNo = const Value.absent(),
                Value<String?> tDate = const Value.absent(),
                Value<int?> accId = const Value.absent(),
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> dr = const Value.absent(),
                Value<double?> cr = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> st = const Value.absent(),
                Value<String?> updateStatus = const Value.absent(),
                Value<String?> currencyStatus = const Value.absent(),
                Value<String?> cashStatus = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
                Value<String?> msgNo = const Value.absent(),
                Value<String?> hwls1 = const Value.absent(),
                Value<String?> hwls = const Value.absent(),
                Value<String?> advanceMess = const Value.absent(),
                Value<int?> cbal = const Value.absent(),
                Value<int?> cbal1 = const Value.absent(),
                Value<String?> tTime = const Value.absent(),
                Value<String?> pd = const Value.absent(),
                Value<String?> msgNo2 = const Value.absent(),
                Value<String?> others = const Value.absent(),
                Value<int?> isSynced = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int?> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsPCompanion.insert(
                voucherNo: voucherNo,
                tDate: tDate,
                accId: accId,
                accTypeId: accTypeId,
                description: description,
                dr: dr,
                cr: cr,
                status: status,
                st: st,
                updateStatus: updateStatus,
                currencyStatus: currencyStatus,
                cashStatus: cashStatus,
                userId: userId,
                companyId: companyId,
                wName: wName,
                msgNo: msgNo,
                hwls1: hwls1,
                hwls: hwls,
                advanceMess: advanceMess,
                cbal: cbal,
                cbal1: cbal1,
                tTime: tTime,
                pd: pd,
                msgNo2: msgNo2,
                others: others,
                isSynced: isSynced,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsPTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsPTable,
      TransactionsPData,
      $$TransactionsPTableFilterComposer,
      $$TransactionsPTableOrderingComposer,
      $$TransactionsPTableAnnotationComposer,
      $$TransactionsPTableCreateCompanionBuilder,
      $$TransactionsPTableUpdateCompanionBuilder,
      (
        TransactionsPData,
        BaseReferences<_$AppDatabase, $TransactionsPTable, TransactionsPData>,
      ),
      TransactionsPData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccPersonalTableTableManager get accPersonal =>
      $$AccPersonalTableTableManager(_db, _db.accPersonal);
  $$AccTypeTableTableManager get accType =>
      $$AccTypeTableTableManager(_db, _db.accType);
  $$CompanyTableTableTableManager get companyTable =>
      $$CompanyTableTableTableManager(_db, _db.companyTable);
  $$DbInfoTableTableTableManager get dbInfoTable =>
      $$DbInfoTableTableTableManager(_db, _db.dbInfoTable);
  $$TransactionsPTableTableManager get transactionsP =>
      $$TransactionsPTableTableManager(_db, _db.transactionsP);
}

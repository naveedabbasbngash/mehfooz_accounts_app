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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accNameMeta = const VerificationMeta(
    'accName',
  );
  @override
  late final GeneratedColumn<String> accName = GeneratedColumn<String>(
    'Name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatherNameMeta = const VerificationMeta(
    'fatherName',
  );
  @override
  late final GeneratedColumn<String> fatherName = GeneratedColumn<String>(
    'FatherName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contact1Meta = const VerificationMeta(
    'contact1',
  );
  @override
  late final GeneratedColumn<String> contact1 = GeneratedColumn<String>(
    'Contact1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contact2Meta = const VerificationMeta(
    'contact2',
  );
  @override
  late final GeneratedColumn<String> contact2 = GeneratedColumn<String>(
    'Contact2',
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'Email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whatsappMeta = const VerificationMeta(
    'whatsapp',
  );
  @override
  late final GeneratedColumn<String> whatsapp = GeneratedColumn<String>(
    'Whatsapp',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _profileImageMeta = const VerificationMeta(
    'profileImage',
  );
  @override
  late final GeneratedColumn<String> profileImage = GeneratedColumn<String>(
    'ProfileImage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _drMeta = const VerificationMeta('dr');
  @override
  late final GeneratedColumn<double> dr = GeneratedColumn<double>(
    'DR',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _crMeta = const VerificationMeta('cr');
  @override
  late final GeneratedColumn<double> cr = GeneratedColumn<double>(
    'CR',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyStatusMeta = const VerificationMeta(
    'currencyStatus',
  );
  @override
  late final GeneratedColumn<String> currencyStatus = GeneratedColumn<String>(
    'CurrencyStatus',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    accId,
    accName,
    fatherName,
    contact1,
    contact2,
    address,
    remarks,
    accTypeId,
    email,
    whatsapp,
    companyName,
    profileImage,
    dr,
    cr,
    currencyStatus,
    companyId,
    wName,
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
    if (data.containsKey('Name')) {
      context.handle(
        _accNameMeta,
        accName.isAcceptableOrUnknown(data['Name']!, _accNameMeta),
      );
    }
    if (data.containsKey('FatherName')) {
      context.handle(
        _fatherNameMeta,
        fatherName.isAcceptableOrUnknown(data['FatherName']!, _fatherNameMeta),
      );
    }
    if (data.containsKey('Contact1')) {
      context.handle(
        _contact1Meta,
        contact1.isAcceptableOrUnknown(data['Contact1']!, _contact1Meta),
      );
    }
    if (data.containsKey('Contact2')) {
      context.handle(
        _contact2Meta,
        contact2.isAcceptableOrUnknown(data['Contact2']!, _contact2Meta),
      );
    }
    if (data.containsKey('Address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['Address']!, _addressMeta),
      );
    }
    if (data.containsKey('Remarks')) {
      context.handle(
        _remarksMeta,
        remarks.isAcceptableOrUnknown(data['Remarks']!, _remarksMeta),
      );
    }
    if (data.containsKey('AccTypeID')) {
      context.handle(
        _accTypeIdMeta,
        accTypeId.isAcceptableOrUnknown(data['AccTypeID']!, _accTypeIdMeta),
      );
    }
    if (data.containsKey('Email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['Email']!, _emailMeta),
      );
    }
    if (data.containsKey('Whatsapp')) {
      context.handle(
        _whatsappMeta,
        whatsapp.isAcceptableOrUnknown(data['Whatsapp']!, _whatsappMeta),
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
    if (data.containsKey('ProfileImage')) {
      context.handle(
        _profileImageMeta,
        profileImage.isAcceptableOrUnknown(
          data['ProfileImage']!,
          _profileImageMeta,
        ),
      );
    }
    if (data.containsKey('DR')) {
      context.handle(_drMeta, dr.isAcceptableOrUnknown(data['DR']!, _drMeta));
    }
    if (data.containsKey('CR')) {
      context.handle(_crMeta, cr.isAcceptableOrUnknown(data['CR']!, _crMeta));
    }
    if (data.containsKey('CurrencyStatus')) {
      context.handle(
        _currencyStatusMeta,
        currencyStatus.isAcceptableOrUnknown(
          data['CurrencyStatus']!,
          _currencyStatusMeta,
        ),
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
      ),
      accName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Name'],
      ),
      fatherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}FatherName'],
      ),
      contact1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Contact1'],
      ),
      contact2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Contact2'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Address'],
      ),
      remarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Remarks'],
      ),
      accTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}AccTypeID'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Email'],
      ),
      whatsapp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}Whatsapp'],
      ),
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}CompanyName'],
      ),
      profileImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ProfileImage'],
      ),
      dr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}DR'],
      ),
      cr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}CR'],
      ),
      currencyStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}CurrencyStatus'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}CompanyID'],
      ),
      wName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}WName'],
      ),
    );
  }

  @override
  $AccPersonalTable createAlias(String alias) {
    return $AccPersonalTable(attachedDatabase, alias);
  }
}

class AccPersonalData extends DataClass implements Insertable<AccPersonalData> {
  final int? accId;
  final String? accName;
  final String? fatherName;
  final String? contact1;
  final String? contact2;
  final String? address;
  final String? remarks;
  final int? accTypeId;
  final String? email;
  final String? whatsapp;
  final String? companyName;
  final String? profileImage;
  final double? dr;
  final double? cr;
  final String? currencyStatus;
  final int? companyId;
  final String? wName;
  const AccPersonalData({
    this.accId,
    this.accName,
    this.fatherName,
    this.contact1,
    this.contact2,
    this.address,
    this.remarks,
    this.accTypeId,
    this.email,
    this.whatsapp,
    this.companyName,
    this.profileImage,
    this.dr,
    this.cr,
    this.currencyStatus,
    this.companyId,
    this.wName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || accId != null) {
      map['AccID'] = Variable<int>(accId);
    }
    if (!nullToAbsent || accName != null) {
      map['Name'] = Variable<String>(accName);
    }
    if (!nullToAbsent || fatherName != null) {
      map['FatherName'] = Variable<String>(fatherName);
    }
    if (!nullToAbsent || contact1 != null) {
      map['Contact1'] = Variable<String>(contact1);
    }
    if (!nullToAbsent || contact2 != null) {
      map['Contact2'] = Variable<String>(contact2);
    }
    if (!nullToAbsent || address != null) {
      map['Address'] = Variable<String>(address);
    }
    if (!nullToAbsent || remarks != null) {
      map['Remarks'] = Variable<String>(remarks);
    }
    if (!nullToAbsent || accTypeId != null) {
      map['AccTypeID'] = Variable<int>(accTypeId);
    }
    if (!nullToAbsent || email != null) {
      map['Email'] = Variable<String>(email);
    }
    if (!nullToAbsent || whatsapp != null) {
      map['Whatsapp'] = Variable<String>(whatsapp);
    }
    if (!nullToAbsent || companyName != null) {
      map['CompanyName'] = Variable<String>(companyName);
    }
    if (!nullToAbsent || profileImage != null) {
      map['ProfileImage'] = Variable<String>(profileImage);
    }
    if (!nullToAbsent || dr != null) {
      map['DR'] = Variable<double>(dr);
    }
    if (!nullToAbsent || cr != null) {
      map['CR'] = Variable<double>(cr);
    }
    if (!nullToAbsent || currencyStatus != null) {
      map['CurrencyStatus'] = Variable<String>(currencyStatus);
    }
    if (!nullToAbsent || companyId != null) {
      map['CompanyID'] = Variable<int>(companyId);
    }
    if (!nullToAbsent || wName != null) {
      map['WName'] = Variable<String>(wName);
    }
    return map;
  }

  AccPersonalCompanion toCompanion(bool nullToAbsent) {
    return AccPersonalCompanion(
      accId: accId == null && nullToAbsent
          ? const Value.absent()
          : Value(accId),
      accName: accName == null && nullToAbsent
          ? const Value.absent()
          : Value(accName),
      fatherName: fatherName == null && nullToAbsent
          ? const Value.absent()
          : Value(fatherName),
      contact1: contact1 == null && nullToAbsent
          ? const Value.absent()
          : Value(contact1),
      contact2: contact2 == null && nullToAbsent
          ? const Value.absent()
          : Value(contact2),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      remarks: remarks == null && nullToAbsent
          ? const Value.absent()
          : Value(remarks),
      accTypeId: accTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeId),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      whatsapp: whatsapp == null && nullToAbsent
          ? const Value.absent()
          : Value(whatsapp),
      companyName: companyName == null && nullToAbsent
          ? const Value.absent()
          : Value(companyName),
      profileImage: profileImage == null && nullToAbsent
          ? const Value.absent()
          : Value(profileImage),
      dr: dr == null && nullToAbsent ? const Value.absent() : Value(dr),
      cr: cr == null && nullToAbsent ? const Value.absent() : Value(cr),
      currencyStatus: currencyStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyStatus),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      wName: wName == null && nullToAbsent
          ? const Value.absent()
          : Value(wName),
    );
  }

  factory AccPersonalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccPersonalData(
      accId: serializer.fromJson<int?>(json['accId']),
      accName: serializer.fromJson<String?>(json['accName']),
      fatherName: serializer.fromJson<String?>(json['fatherName']),
      contact1: serializer.fromJson<String?>(json['contact1']),
      contact2: serializer.fromJson<String?>(json['contact2']),
      address: serializer.fromJson<String?>(json['address']),
      remarks: serializer.fromJson<String?>(json['remarks']),
      accTypeId: serializer.fromJson<int?>(json['accTypeId']),
      email: serializer.fromJson<String?>(json['email']),
      whatsapp: serializer.fromJson<String?>(json['whatsapp']),
      companyName: serializer.fromJson<String?>(json['companyName']),
      profileImage: serializer.fromJson<String?>(json['profileImage']),
      dr: serializer.fromJson<double?>(json['dr']),
      cr: serializer.fromJson<double?>(json['cr']),
      currencyStatus: serializer.fromJson<String?>(json['currencyStatus']),
      companyId: serializer.fromJson<int?>(json['companyId']),
      wName: serializer.fromJson<String?>(json['wName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accId': serializer.toJson<int?>(accId),
      'accName': serializer.toJson<String?>(accName),
      'fatherName': serializer.toJson<String?>(fatherName),
      'contact1': serializer.toJson<String?>(contact1),
      'contact2': serializer.toJson<String?>(contact2),
      'address': serializer.toJson<String?>(address),
      'remarks': serializer.toJson<String?>(remarks),
      'accTypeId': serializer.toJson<int?>(accTypeId),
      'email': serializer.toJson<String?>(email),
      'whatsapp': serializer.toJson<String?>(whatsapp),
      'companyName': serializer.toJson<String?>(companyName),
      'profileImage': serializer.toJson<String?>(profileImage),
      'dr': serializer.toJson<double?>(dr),
      'cr': serializer.toJson<double?>(cr),
      'currencyStatus': serializer.toJson<String?>(currencyStatus),
      'companyId': serializer.toJson<int?>(companyId),
      'wName': serializer.toJson<String?>(wName),
    };
  }

  AccPersonalData copyWith({
    Value<int?> accId = const Value.absent(),
    Value<String?> accName = const Value.absent(),
    Value<String?> fatherName = const Value.absent(),
    Value<String?> contact1 = const Value.absent(),
    Value<String?> contact2 = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> remarks = const Value.absent(),
    Value<int?> accTypeId = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> whatsapp = const Value.absent(),
    Value<String?> companyName = const Value.absent(),
    Value<String?> profileImage = const Value.absent(),
    Value<double?> dr = const Value.absent(),
    Value<double?> cr = const Value.absent(),
    Value<String?> currencyStatus = const Value.absent(),
    Value<int?> companyId = const Value.absent(),
    Value<String?> wName = const Value.absent(),
  }) => AccPersonalData(
    accId: accId.present ? accId.value : this.accId,
    accName: accName.present ? accName.value : this.accName,
    fatherName: fatherName.present ? fatherName.value : this.fatherName,
    contact1: contact1.present ? contact1.value : this.contact1,
    contact2: contact2.present ? contact2.value : this.contact2,
    address: address.present ? address.value : this.address,
    remarks: remarks.present ? remarks.value : this.remarks,
    accTypeId: accTypeId.present ? accTypeId.value : this.accTypeId,
    email: email.present ? email.value : this.email,
    whatsapp: whatsapp.present ? whatsapp.value : this.whatsapp,
    companyName: companyName.present ? companyName.value : this.companyName,
    profileImage: profileImage.present ? profileImage.value : this.profileImage,
    dr: dr.present ? dr.value : this.dr,
    cr: cr.present ? cr.value : this.cr,
    currencyStatus: currencyStatus.present
        ? currencyStatus.value
        : this.currencyStatus,
    companyId: companyId.present ? companyId.value : this.companyId,
    wName: wName.present ? wName.value : this.wName,
  );
  AccPersonalData copyWithCompanion(AccPersonalCompanion data) {
    return AccPersonalData(
      accId: data.accId.present ? data.accId.value : this.accId,
      accName: data.accName.present ? data.accName.value : this.accName,
      fatherName: data.fatherName.present
          ? data.fatherName.value
          : this.fatherName,
      contact1: data.contact1.present ? data.contact1.value : this.contact1,
      contact2: data.contact2.present ? data.contact2.value : this.contact2,
      address: data.address.present ? data.address.value : this.address,
      remarks: data.remarks.present ? data.remarks.value : this.remarks,
      accTypeId: data.accTypeId.present ? data.accTypeId.value : this.accTypeId,
      email: data.email.present ? data.email.value : this.email,
      whatsapp: data.whatsapp.present ? data.whatsapp.value : this.whatsapp,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      profileImage: data.profileImage.present
          ? data.profileImage.value
          : this.profileImage,
      dr: data.dr.present ? data.dr.value : this.dr,
      cr: data.cr.present ? data.cr.value : this.cr,
      currencyStatus: data.currencyStatus.present
          ? data.currencyStatus.value
          : this.currencyStatus,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      wName: data.wName.present ? data.wName.value : this.wName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccPersonalData(')
          ..write('accId: $accId, ')
          ..write('accName: $accName, ')
          ..write('fatherName: $fatherName, ')
          ..write('contact1: $contact1, ')
          ..write('contact2: $contact2, ')
          ..write('address: $address, ')
          ..write('remarks: $remarks, ')
          ..write('accTypeId: $accTypeId, ')
          ..write('email: $email, ')
          ..write('whatsapp: $whatsapp, ')
          ..write('companyName: $companyName, ')
          ..write('profileImage: $profileImage, ')
          ..write('dr: $dr, ')
          ..write('cr: $cr, ')
          ..write('currencyStatus: $currencyStatus, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accId,
    accName,
    fatherName,
    contact1,
    contact2,
    address,
    remarks,
    accTypeId,
    email,
    whatsapp,
    companyName,
    profileImage,
    dr,
    cr,
    currencyStatus,
    companyId,
    wName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccPersonalData &&
          other.accId == this.accId &&
          other.accName == this.accName &&
          other.fatherName == this.fatherName &&
          other.contact1 == this.contact1 &&
          other.contact2 == this.contact2 &&
          other.address == this.address &&
          other.remarks == this.remarks &&
          other.accTypeId == this.accTypeId &&
          other.email == this.email &&
          other.whatsapp == this.whatsapp &&
          other.companyName == this.companyName &&
          other.profileImage == this.profileImage &&
          other.dr == this.dr &&
          other.cr == this.cr &&
          other.currencyStatus == this.currencyStatus &&
          other.companyId == this.companyId &&
          other.wName == this.wName);
}

class AccPersonalCompanion extends UpdateCompanion<AccPersonalData> {
  final Value<int?> accId;
  final Value<String?> accName;
  final Value<String?> fatherName;
  final Value<String?> contact1;
  final Value<String?> contact2;
  final Value<String?> address;
  final Value<String?> remarks;
  final Value<int?> accTypeId;
  final Value<String?> email;
  final Value<String?> whatsapp;
  final Value<String?> companyName;
  final Value<String?> profileImage;
  final Value<double?> dr;
  final Value<double?> cr;
  final Value<String?> currencyStatus;
  final Value<int?> companyId;
  final Value<String?> wName;
  const AccPersonalCompanion({
    this.accId = const Value.absent(),
    this.accName = const Value.absent(),
    this.fatherName = const Value.absent(),
    this.contact1 = const Value.absent(),
    this.contact2 = const Value.absent(),
    this.address = const Value.absent(),
    this.remarks = const Value.absent(),
    this.accTypeId = const Value.absent(),
    this.email = const Value.absent(),
    this.whatsapp = const Value.absent(),
    this.companyName = const Value.absent(),
    this.profileImage = const Value.absent(),
    this.dr = const Value.absent(),
    this.cr = const Value.absent(),
    this.currencyStatus = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
  });
  AccPersonalCompanion.insert({
    this.accId = const Value.absent(),
    this.accName = const Value.absent(),
    this.fatherName = const Value.absent(),
    this.contact1 = const Value.absent(),
    this.contact2 = const Value.absent(),
    this.address = const Value.absent(),
    this.remarks = const Value.absent(),
    this.accTypeId = const Value.absent(),
    this.email = const Value.absent(),
    this.whatsapp = const Value.absent(),
    this.companyName = const Value.absent(),
    this.profileImage = const Value.absent(),
    this.dr = const Value.absent(),
    this.cr = const Value.absent(),
    this.currencyStatus = const Value.absent(),
    this.companyId = const Value.absent(),
    this.wName = const Value.absent(),
  });
  static Insertable<AccPersonalData> custom({
    Expression<int>? accId,
    Expression<String>? accName,
    Expression<String>? fatherName,
    Expression<String>? contact1,
    Expression<String>? contact2,
    Expression<String>? address,
    Expression<String>? remarks,
    Expression<int>? accTypeId,
    Expression<String>? email,
    Expression<String>? whatsapp,
    Expression<String>? companyName,
    Expression<String>? profileImage,
    Expression<double>? dr,
    Expression<double>? cr,
    Expression<String>? currencyStatus,
    Expression<int>? companyId,
    Expression<String>? wName,
  }) {
    return RawValuesInsertable({
      if (accId != null) 'AccID': accId,
      if (accName != null) 'Name': accName,
      if (fatherName != null) 'FatherName': fatherName,
      if (contact1 != null) 'Contact1': contact1,
      if (contact2 != null) 'Contact2': contact2,
      if (address != null) 'Address': address,
      if (remarks != null) 'Remarks': remarks,
      if (accTypeId != null) 'AccTypeID': accTypeId,
      if (email != null) 'Email': email,
      if (whatsapp != null) 'Whatsapp': whatsapp,
      if (companyName != null) 'CompanyName': companyName,
      if (profileImage != null) 'ProfileImage': profileImage,
      if (dr != null) 'DR': dr,
      if (cr != null) 'CR': cr,
      if (currencyStatus != null) 'CurrencyStatus': currencyStatus,
      if (companyId != null) 'CompanyID': companyId,
      if (wName != null) 'WName': wName,
    });
  }

  AccPersonalCompanion copyWith({
    Value<int?>? accId,
    Value<String?>? accName,
    Value<String?>? fatherName,
    Value<String?>? contact1,
    Value<String?>? contact2,
    Value<String?>? address,
    Value<String?>? remarks,
    Value<int?>? accTypeId,
    Value<String?>? email,
    Value<String?>? whatsapp,
    Value<String?>? companyName,
    Value<String?>? profileImage,
    Value<double?>? dr,
    Value<double?>? cr,
    Value<String?>? currencyStatus,
    Value<int?>? companyId,
    Value<String?>? wName,
  }) {
    return AccPersonalCompanion(
      accId: accId ?? this.accId,
      accName: accName ?? this.accName,
      fatherName: fatherName ?? this.fatherName,
      contact1: contact1 ?? this.contact1,
      contact2: contact2 ?? this.contact2,
      address: address ?? this.address,
      remarks: remarks ?? this.remarks,
      accTypeId: accTypeId ?? this.accTypeId,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      companyName: companyName ?? this.companyName,
      profileImage: profileImage ?? this.profileImage,
      dr: dr ?? this.dr,
      cr: cr ?? this.cr,
      currencyStatus: currencyStatus ?? this.currencyStatus,
      companyId: companyId ?? this.companyId,
      wName: wName ?? this.wName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accId.present) {
      map['AccID'] = Variable<int>(accId.value);
    }
    if (accName.present) {
      map['Name'] = Variable<String>(accName.value);
    }
    if (fatherName.present) {
      map['FatherName'] = Variable<String>(fatherName.value);
    }
    if (contact1.present) {
      map['Contact1'] = Variable<String>(contact1.value);
    }
    if (contact2.present) {
      map['Contact2'] = Variable<String>(contact2.value);
    }
    if (address.present) {
      map['Address'] = Variable<String>(address.value);
    }
    if (remarks.present) {
      map['Remarks'] = Variable<String>(remarks.value);
    }
    if (accTypeId.present) {
      map['AccTypeID'] = Variable<int>(accTypeId.value);
    }
    if (email.present) {
      map['Email'] = Variable<String>(email.value);
    }
    if (whatsapp.present) {
      map['Whatsapp'] = Variable<String>(whatsapp.value);
    }
    if (companyName.present) {
      map['CompanyName'] = Variable<String>(companyName.value);
    }
    if (profileImage.present) {
      map['ProfileImage'] = Variable<String>(profileImage.value);
    }
    if (dr.present) {
      map['DR'] = Variable<double>(dr.value);
    }
    if (cr.present) {
      map['CR'] = Variable<double>(cr.value);
    }
    if (currencyStatus.present) {
      map['CurrencyStatus'] = Variable<String>(currencyStatus.value);
    }
    if (companyId.present) {
      map['CompanyID'] = Variable<int>(companyId.value);
    }
    if (wName.present) {
      map['WName'] = Variable<String>(wName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccPersonalCompanion(')
          ..write('accId: $accId, ')
          ..write('accName: $accName, ')
          ..write('fatherName: $fatherName, ')
          ..write('contact1: $contact1, ')
          ..write('contact2: $contact2, ')
          ..write('address: $address, ')
          ..write('remarks: $remarks, ')
          ..write('accTypeId: $accTypeId, ')
          ..write('email: $email, ')
          ..write('whatsapp: $whatsapp, ')
          ..write('companyName: $companyName, ')
          ..write('profileImage: $profileImage, ')
          ..write('dr: $dr, ')
          ..write('cr: $cr, ')
          ..write('currencyStatus: $currencyStatus, ')
          ..write('companyId: $companyId, ')
          ..write('wName: $wName')
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
    true,
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
  @override
  List<GeneratedColumn> get $columns => [
    accTypeId,
    accTypeName,
    accTypeNameU,
    flag,
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
      ),
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
    );
  }

  @override
  $AccTypeTable createAlias(String alias) {
    return $AccTypeTable(attachedDatabase, alias);
  }
}

class AccTypeData extends DataClass implements Insertable<AccTypeData> {
  final int? accTypeId;
  final String? accTypeName;
  final String? accTypeNameU;
  final String? flag;
  const AccTypeData({
    this.accTypeId,
    this.accTypeName,
    this.accTypeNameU,
    this.flag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || accTypeId != null) {
      map['AccTypeID'] = Variable<int>(accTypeId);
    }
    if (!nullToAbsent || accTypeName != null) {
      map['AccTypeName'] = Variable<String>(accTypeName);
    }
    if (!nullToAbsent || accTypeNameU != null) {
      map['AccTypeNameu'] = Variable<String>(accTypeNameU);
    }
    if (!nullToAbsent || flag != null) {
      map['FLAG'] = Variable<String>(flag);
    }
    return map;
  }

  AccTypeCompanion toCompanion(bool nullToAbsent) {
    return AccTypeCompanion(
      accTypeId: accTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeId),
      accTypeName: accTypeName == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeName),
      accTypeNameU: accTypeNameU == null && nullToAbsent
          ? const Value.absent()
          : Value(accTypeNameU),
      flag: flag == null && nullToAbsent ? const Value.absent() : Value(flag),
    );
  }

  factory AccTypeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccTypeData(
      accTypeId: serializer.fromJson<int?>(json['accTypeId']),
      accTypeName: serializer.fromJson<String?>(json['accTypeName']),
      accTypeNameU: serializer.fromJson<String?>(json['accTypeNameU']),
      flag: serializer.fromJson<String?>(json['flag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accTypeId': serializer.toJson<int?>(accTypeId),
      'accTypeName': serializer.toJson<String?>(accTypeName),
      'accTypeNameU': serializer.toJson<String?>(accTypeNameU),
      'flag': serializer.toJson<String?>(flag),
    };
  }

  AccTypeData copyWith({
    Value<int?> accTypeId = const Value.absent(),
    Value<String?> accTypeName = const Value.absent(),
    Value<String?> accTypeNameU = const Value.absent(),
    Value<String?> flag = const Value.absent(),
  }) => AccTypeData(
    accTypeId: accTypeId.present ? accTypeId.value : this.accTypeId,
    accTypeName: accTypeName.present ? accTypeName.value : this.accTypeName,
    accTypeNameU: accTypeNameU.present ? accTypeNameU.value : this.accTypeNameU,
    flag: flag.present ? flag.value : this.flag,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccTypeData(')
          ..write('accTypeId: $accTypeId, ')
          ..write('accTypeName: $accTypeName, ')
          ..write('accTypeNameU: $accTypeNameU, ')
          ..write('flag: $flag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accTypeId, accTypeName, accTypeNameU, flag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccTypeData &&
          other.accTypeId == this.accTypeId &&
          other.accTypeName == this.accTypeName &&
          other.accTypeNameU == this.accTypeNameU &&
          other.flag == this.flag);
}

class AccTypeCompanion extends UpdateCompanion<AccTypeData> {
  final Value<int?> accTypeId;
  final Value<String?> accTypeName;
  final Value<String?> accTypeNameU;
  final Value<String?> flag;
  const AccTypeCompanion({
    this.accTypeId = const Value.absent(),
    this.accTypeName = const Value.absent(),
    this.accTypeNameU = const Value.absent(),
    this.flag = const Value.absent(),
  });
  AccTypeCompanion.insert({
    this.accTypeId = const Value.absent(),
    this.accTypeName = const Value.absent(),
    this.accTypeNameU = const Value.absent(),
    this.flag = const Value.absent(),
  });
  static Insertable<AccTypeData> custom({
    Expression<int>? accTypeId,
    Expression<String>? accTypeName,
    Expression<String>? accTypeNameU,
    Expression<String>? flag,
  }) {
    return RawValuesInsertable({
      if (accTypeId != null) 'AccTypeID': accTypeId,
      if (accTypeName != null) 'AccTypeName': accTypeName,
      if (accTypeNameU != null) 'AccTypeNameu': accTypeNameU,
      if (flag != null) 'FLAG': flag,
    });
  }

  AccTypeCompanion copyWith({
    Value<int?>? accTypeId,
    Value<String?>? accTypeName,
    Value<String?>? accTypeNameU,
    Value<String?>? flag,
  }) {
    return AccTypeCompanion(
      accTypeId: accTypeId ?? this.accTypeId,
      accTypeName: accTypeName ?? this.accTypeName,
      accTypeNameU: accTypeNameU ?? this.accTypeNameU,
      flag: flag ?? this.flag,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccTypeCompanion(')
          ..write('accTypeId: $accTypeId, ')
          ..write('accTypeName: $accTypeName, ')
          ..write('accTypeNameU: $accTypeNameU, ')
          ..write('flag: $flag')
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
    true,
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
      ),
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
  final int? companyId;
  final String? companyName;
  final String? remarks;
  const CompanyTableData({this.companyId, this.companyName, this.remarks});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || companyId != null) {
      map['CompanyID'] = Variable<int>(companyId);
    }
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
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
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
      companyId: serializer.fromJson<int?>(json['companyId']),
      companyName: serializer.fromJson<String?>(json['companyName']),
      remarks: serializer.fromJson<String?>(json['remarks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<int?>(companyId),
      'companyName': serializer.toJson<String?>(companyName),
      'remarks': serializer.toJson<String?>(remarks),
    };
  }

  CompanyTableData copyWith({
    Value<int?> companyId = const Value.absent(),
    Value<String?> companyName = const Value.absent(),
    Value<String?> remarks = const Value.absent(),
  }) => CompanyTableData(
    companyId: companyId.present ? companyId.value : this.companyId,
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
  final Value<int?> companyId;
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
    Value<int?>? companyId,
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
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _voucherNoMeta = const VerificationMeta(
    'voucherNo',
  );
  @override
  late final GeneratedColumn<int> voucherNo = GeneratedColumn<int>(
    'VoucherNo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tdateMeta = const VerificationMeta('tdate');
  @override
  late final GeneratedColumn<String> tdate = GeneratedColumn<String>(
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
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    voucherNo,
    tdate,
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
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('VoucherNo')) {
      context.handle(
        _voucherNoMeta,
        voucherNo.isAcceptableOrUnknown(data['VoucherNo']!, _voucherNoMeta),
      );
    }
    if (data.containsKey('TDate')) {
      context.handle(
        _tdateMeta,
        tdate.isAcceptableOrUnknown(data['TDate']!, _tdateMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  TransactionsPData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionsPData(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      voucherNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}VoucherNo'],
      ),
      tdate: attachedDatabase.typeMapping.read(
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
    );
  }

  @override
  $TransactionsPTable createAlias(String alias) {
    return $TransactionsPTable(attachedDatabase, alias);
  }
}

class TransactionsPData extends DataClass
    implements Insertable<TransactionsPData> {
  /// SQLite has no PK → generate one
  final int rowId;
  final int? voucherNo;
  final String? tdate;
  final int? accId;
  final int? accTypeId;

  /// SQL COLUMN: Description (NOT Narr)
  final String? description;
  final double? dr;
  final double? cr;
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

  /// BIT → stored as INTEGER (0/1)
  final int? cbal;
  final int? cbal1;
  final String? tTime;
  final String? pd;
  final String? msgNo2;
  final String? others;
  const TransactionsPData({
    required this.rowId,
    this.voucherNo,
    this.tdate,
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
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    if (!nullToAbsent || voucherNo != null) {
      map['VoucherNo'] = Variable<int>(voucherNo);
    }
    if (!nullToAbsent || tdate != null) {
      map['TDate'] = Variable<String>(tdate);
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
    return map;
  }

  TransactionsPCompanion toCompanion(bool nullToAbsent) {
    return TransactionsPCompanion(
      rowId: Value(rowId),
      voucherNo: voucherNo == null && nullToAbsent
          ? const Value.absent()
          : Value(voucherNo),
      tdate: tdate == null && nullToAbsent
          ? const Value.absent()
          : Value(tdate),
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
    );
  }

  factory TransactionsPData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionsPData(
      rowId: serializer.fromJson<int>(json['rowId']),
      voucherNo: serializer.fromJson<int?>(json['voucherNo']),
      tdate: serializer.fromJson<String?>(json['tdate']),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'voucherNo': serializer.toJson<int?>(voucherNo),
      'tdate': serializer.toJson<String?>(tdate),
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
    };
  }

  TransactionsPData copyWith({
    int? rowId,
    Value<int?> voucherNo = const Value.absent(),
    Value<String?> tdate = const Value.absent(),
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
  }) => TransactionsPData(
    rowId: rowId ?? this.rowId,
    voucherNo: voucherNo.present ? voucherNo.value : this.voucherNo,
    tdate: tdate.present ? tdate.value : this.tdate,
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
  );
  TransactionsPData copyWithCompanion(TransactionsPCompanion data) {
    return TransactionsPData(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      voucherNo: data.voucherNo.present ? data.voucherNo.value : this.voucherNo,
      tdate: data.tdate.present ? data.tdate.value : this.tdate,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsPData(')
          ..write('rowId: $rowId, ')
          ..write('voucherNo: $voucherNo, ')
          ..write('tdate: $tdate, ')
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
          ..write('others: $others')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    rowId,
    voucherNo,
    tdate,
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
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionsPData &&
          other.rowId == this.rowId &&
          other.voucherNo == this.voucherNo &&
          other.tdate == this.tdate &&
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
          other.others == this.others);
}

class TransactionsPCompanion extends UpdateCompanion<TransactionsPData> {
  final Value<int> rowId;
  final Value<int?> voucherNo;
  final Value<String?> tdate;
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
  const TransactionsPCompanion({
    this.rowId = const Value.absent(),
    this.voucherNo = const Value.absent(),
    this.tdate = const Value.absent(),
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
  });
  TransactionsPCompanion.insert({
    this.rowId = const Value.absent(),
    this.voucherNo = const Value.absent(),
    this.tdate = const Value.absent(),
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
  });
  static Insertable<TransactionsPData> custom({
    Expression<int>? rowId,
    Expression<int>? voucherNo,
    Expression<String>? tdate,
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
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (voucherNo != null) 'VoucherNo': voucherNo,
      if (tdate != null) 'TDate': tdate,
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
    });
  }

  TransactionsPCompanion copyWith({
    Value<int>? rowId,
    Value<int?>? voucherNo,
    Value<String?>? tdate,
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
  }) {
    return TransactionsPCompanion(
      rowId: rowId ?? this.rowId,
      voucherNo: voucherNo ?? this.voucherNo,
      tdate: tdate ?? this.tdate,
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
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (voucherNo.present) {
      map['VoucherNo'] = Variable<int>(voucherNo.value);
    }
    if (tdate.present) {
      map['TDate'] = Variable<String>(tdate.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsPCompanion(')
          ..write('rowId: $rowId, ')
          ..write('voucherNo: $voucherNo, ')
          ..write('tdate: $tdate, ')
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
          ..write('others: $others')
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
      Value<int?> accId,
      Value<String?> accName,
      Value<String?> fatherName,
      Value<String?> contact1,
      Value<String?> contact2,
      Value<String?> address,
      Value<String?> remarks,
      Value<int?> accTypeId,
      Value<String?> email,
      Value<String?> whatsapp,
      Value<String?> companyName,
      Value<String?> profileImage,
      Value<double?> dr,
      Value<double?> cr,
      Value<String?> currencyStatus,
      Value<int?> companyId,
      Value<String?> wName,
    });
typedef $$AccPersonalTableUpdateCompanionBuilder =
    AccPersonalCompanion Function({
      Value<int?> accId,
      Value<String?> accName,
      Value<String?> fatherName,
      Value<String?> contact1,
      Value<String?> contact2,
      Value<String?> address,
      Value<String?> remarks,
      Value<int?> accTypeId,
      Value<String?> email,
      Value<String?> whatsapp,
      Value<String?> companyName,
      Value<String?> profileImage,
      Value<double?> dr,
      Value<double?> cr,
      Value<String?> currencyStatus,
      Value<int?> companyId,
      Value<String?> wName,
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

  ColumnFilters<String> get accName => $composableBuilder(
    column: $table.accName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact1 => $composableBuilder(
    column: $table.contact1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact2 => $composableBuilder(
    column: $table.contact2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whatsapp => $composableBuilder(
    column: $table.whatsapp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
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

  ColumnFilters<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
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

  ColumnOrderings<String> get accName => $composableBuilder(
    column: $table.accName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact1 => $composableBuilder(
    column: $table.contact1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact2 => $composableBuilder(
    column: $table.contact2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remarks => $composableBuilder(
    column: $table.remarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accTypeId => $composableBuilder(
    column: $table.accTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whatsapp => $composableBuilder(
    column: $table.whatsapp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
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

  ColumnOrderings<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
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

  GeneratedColumn<String> get accName =>
      $composableBuilder(column: $table.accName, builder: (column) => column);

  GeneratedColumn<String> get fatherName => $composableBuilder(
    column: $table.fatherName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contact1 =>
      $composableBuilder(column: $table.contact1, builder: (column) => column);

  GeneratedColumn<String> get contact2 =>
      $composableBuilder(column: $table.contact2, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get remarks =>
      $composableBuilder(column: $table.remarks, builder: (column) => column);

  GeneratedColumn<int> get accTypeId =>
      $composableBuilder(column: $table.accTypeId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get whatsapp =>
      $composableBuilder(column: $table.whatsapp, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dr =>
      $composableBuilder(column: $table.dr, builder: (column) => column);

  GeneratedColumn<double> get cr =>
      $composableBuilder(column: $table.cr, builder: (column) => column);

  GeneratedColumn<String> get currencyStatus => $composableBuilder(
    column: $table.currencyStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get wName =>
      $composableBuilder(column: $table.wName, builder: (column) => column);
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
                Value<int?> accId = const Value.absent(),
                Value<String?> accName = const Value.absent(),
                Value<String?> fatherName = const Value.absent(),
                Value<String?> contact1 = const Value.absent(),
                Value<String?> contact2 = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> whatsapp = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> profileImage = const Value.absent(),
                Value<double?> dr = const Value.absent(),
                Value<double?> cr = const Value.absent(),
                Value<String?> currencyStatus = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
              }) => AccPersonalCompanion(
                accId: accId,
                accName: accName,
                fatherName: fatherName,
                contact1: contact1,
                contact2: contact2,
                address: address,
                remarks: remarks,
                accTypeId: accTypeId,
                email: email,
                whatsapp: whatsapp,
                companyName: companyName,
                profileImage: profileImage,
                dr: dr,
                cr: cr,
                currencyStatus: currencyStatus,
                companyId: companyId,
                wName: wName,
              ),
          createCompanionCallback:
              ({
                Value<int?> accId = const Value.absent(),
                Value<String?> accName = const Value.absent(),
                Value<String?> fatherName = const Value.absent(),
                Value<String?> contact1 = const Value.absent(),
                Value<String?> contact2 = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> whatsapp = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> profileImage = const Value.absent(),
                Value<double?> dr = const Value.absent(),
                Value<double?> cr = const Value.absent(),
                Value<String?> currencyStatus = const Value.absent(),
                Value<int?> companyId = const Value.absent(),
                Value<String?> wName = const Value.absent(),
              }) => AccPersonalCompanion.insert(
                accId: accId,
                accName: accName,
                fatherName: fatherName,
                contact1: contact1,
                contact2: contact2,
                address: address,
                remarks: remarks,
                accTypeId: accTypeId,
                email: email,
                whatsapp: whatsapp,
                companyName: companyName,
                profileImage: profileImage,
                dr: dr,
                cr: cr,
                currencyStatus: currencyStatus,
                companyId: companyId,
                wName: wName,
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
      Value<int?> accTypeId,
      Value<String?> accTypeName,
      Value<String?> accTypeNameU,
      Value<String?> flag,
    });
typedef $$AccTypeTableUpdateCompanionBuilder =
    AccTypeCompanion Function({
      Value<int?> accTypeId,
      Value<String?> accTypeName,
      Value<String?> accTypeNameU,
      Value<String?> flag,
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
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> accTypeName = const Value.absent(),
                Value<String?> accTypeNameU = const Value.absent(),
                Value<String?> flag = const Value.absent(),
              }) => AccTypeCompanion(
                accTypeId: accTypeId,
                accTypeName: accTypeName,
                accTypeNameU: accTypeNameU,
                flag: flag,
              ),
          createCompanionCallback:
              ({
                Value<int?> accTypeId = const Value.absent(),
                Value<String?> accTypeName = const Value.absent(),
                Value<String?> accTypeNameU = const Value.absent(),
                Value<String?> flag = const Value.absent(),
              }) => AccTypeCompanion.insert(
                accTypeId: accTypeId,
                accTypeName: accTypeName,
                accTypeNameU: accTypeNameU,
                flag: flag,
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
      Value<int?> companyId,
      Value<String?> companyName,
      Value<String?> remarks,
    });
typedef $$CompanyTableTableUpdateCompanionBuilder =
    CompanyTableCompanion Function({
      Value<int?> companyId,
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
                Value<int?> companyId = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> remarks = const Value.absent(),
              }) => CompanyTableCompanion(
                companyId: companyId,
                companyName: companyName,
                remarks: remarks,
              ),
          createCompanionCallback:
              ({
                Value<int?> companyId = const Value.absent(),
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
      Value<int> rowId,
      Value<int?> voucherNo,
      Value<String?> tdate,
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
    });
typedef $$TransactionsPTableUpdateCompanionBuilder =
    TransactionsPCompanion Function({
      Value<int> rowId,
      Value<int?> voucherNo,
      Value<String?> tdate,
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
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voucherNo => $composableBuilder(
    column: $table.voucherNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tdate => $composableBuilder(
    column: $table.tdate,
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
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voucherNo => $composableBuilder(
    column: $table.voucherNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tdate => $composableBuilder(
    column: $table.tdate,
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
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get voucherNo =>
      $composableBuilder(column: $table.voucherNo, builder: (column) => column);

  GeneratedColumn<String> get tdate =>
      $composableBuilder(column: $table.tdate, builder: (column) => column);

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
                Value<int> rowId = const Value.absent(),
                Value<int?> voucherNo = const Value.absent(),
                Value<String?> tdate = const Value.absent(),
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
              }) => TransactionsPCompanion(
                rowId: rowId,
                voucherNo: voucherNo,
                tdate: tdate,
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
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<int?> voucherNo = const Value.absent(),
                Value<String?> tdate = const Value.absent(),
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
              }) => TransactionsPCompanion.insert(
                rowId: rowId,
                voucherNo: voucherNo,
                tdate: tdate,
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

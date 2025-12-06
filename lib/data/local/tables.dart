import 'package:drift/drift.dart';

/// ========================================================
/// ACC PERSONAL  (SQLite: Acc_Personal)
/// ========================================================
class AccPersonal extends Table {
  @override
  String get tableName => 'Acc_Personal';

  IntColumn get accId => integer().named('AccID')();

  TextColumn get rDate => text().named('RDate').nullable()();
  TextColumn get name => text().named('Name').nullable()();
  TextColumn get phone => text().named('Phone').nullable()();
  TextColumn get fax => text().named('Fax').nullable()();
  TextColumn get address => text().named('Address').nullable()();
  TextColumn get description => text().named('Description').nullable()();
  TextColumn get uAccName => text().named('UAccName').nullable()();

  /// YOUR DB stores this as TEXT (you confirmed)
  TextColumn get statusg => text().named('statusg').nullable()();

  IntColumn get userId => integer().named('UserID').nullable()();
  IntColumn get companyId => integer().named('CompanyID').nullable()();

  TextColumn get wName => text().named('WName').nullable()();

  IntColumn get isSynced => integer().named('IsSynced').nullable()();
  TextColumn get updatedAt => text().named('UpdatedAt').nullable()();
  IntColumn get isDeleted => integer().named('IsDeleted').nullable()();

  @override
  Set<Column> get primaryKey => {accId};
}

/// ========================================================
/// ACC TYPE
/// ========================================================
class AccType extends Table {
  @override
  String get tableName => 'AccType';

  IntColumn get accTypeId => integer().named('AccTypeID')();
  TextColumn get accTypeName => text().named('AccTypeName').nullable()();
  TextColumn get accTypeNameU => text().named('AccTypeNameu').nullable()();
  TextColumn get flag => text().named('FLAG').nullable()();

  IntColumn get isSynced => integer().named('IsSynced').nullable()();
  TextColumn get updatedAt => text().named('UpdatedAt').nullable()();

  @override
  Set<Column> get primaryKey => {accTypeId};
}

/// ========================================================
/// COMPANY
/// ========================================================
class CompanyTable extends Table {
  @override
  String get tableName => 'Company';

  IntColumn get companyId => integer().named('CompanyID')();
  TextColumn get companyName => text().named('CompanyName').nullable()();
  TextColumn get remarks => text().named('Remarks').nullable()();

  @override
  Set<Column> get primaryKey => {companyId};
}

/// ========================================================
/// DB INFO
/// ========================================================
class DbInfoTable extends Table {
  @override
  String get tableName => 'Db_Info';

  TextColumn get emailAddress => text().named('email_address').nullable()();
  TextColumn get databaseName => text().named('database_name').nullable()();
}

/// ========================================================
/// TRANSACTIONS (SQLite: Transactions_P)
/// ========================================================
class TransactionsP extends Table {
  @override
  String get tableName => 'Transactions_P';

  RealColumn get voucherNo => real().named('VoucherNo').nullable()();
  TextColumn get tDate => text().named('TDate').nullable()();
  IntColumn get accId => integer().named('AccID').nullable()();
  IntColumn get accTypeId => integer().named('AccTypeID').nullable()();
  TextColumn get description => text().named('Description').nullable()();

  RealColumn get dr => real().named('Dr').nullable()();
  RealColumn get cr => real().named('Cr').nullable()();

  /// These are TEXT in SQLite — must remain TEXT!
  TextColumn get status => text().named('Status').nullable()();
  TextColumn get st => text().named('st').nullable()();
  TextColumn get updateStatus => text().named('updatestatus').nullable()();
  TextColumn get currencyStatus => text().named('currencystatus').nullable()();
  TextColumn get cashStatus => text().named('cashstatus').nullable()();

  IntColumn get userId => integer().named('UserID').nullable()();
  IntColumn get companyId => integer().named('CompanyID').nullable()();

  TextColumn get wName => text().named('WName').nullable()();
  TextColumn get msgNo => text().named('msgno').nullable()();
  TextColumn get hwls1 => text().named('hwls1').nullable()();
  TextColumn get hwls => text().named('hwls').nullable()();
  TextColumn get advanceMess => text().named('advancemess').nullable()();

  /// These are INTEGER in SQLite
  IntColumn get cbal => integer().named('cbal').nullable()();
  IntColumn get cbal1 => integer().named('cbal1').nullable()();

  TextColumn get tTime => text().named('TTIME').nullable()();
  TextColumn get pd => text().named('PD').nullable()();
  TextColumn get msgNo2 => text().named('msgno2').nullable()();
  TextColumn get others => text().named('OTHERS').nullable()();

  IntColumn get isSynced => integer().named('IsSynced').nullable()();
  TextColumn get updatedAt => text().named('UpdatedAt').nullable()();
  IntColumn get isDeleted => integer().named('IsDeleted').nullable()();
}
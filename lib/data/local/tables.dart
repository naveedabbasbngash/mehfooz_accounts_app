import 'package:drift/drift.dart';

/// ========================================================
/// ACC PERSONAL  (SQL: Acc_Personal)
/// ========================================================
class AccPersonal extends Table {
  @override
  String get tableName => 'Acc_Personal';

  // PRIMARY KEY (nullable in DB, but used as PK here)
  IntColumn get accId => integer().named('AccID').nullable()();

  TextColumn get accName => text().named('Name').nullable()();
  TextColumn get fatherName => text().named('FatherName').nullable()();
  TextColumn get contact1 => text().named('Contact1').nullable()();
  TextColumn get contact2 => text().named('Contact2').nullable()();
  TextColumn get address => text().named('Address').nullable()();
  TextColumn get remarks => text().named('Remarks').nullable()();

  IntColumn get accTypeId => integer().named('AccTypeID').nullable()();

  TextColumn get email => text().named('Email').nullable()();
  TextColumn get whatsapp => text().named('Whatsapp').nullable()();

  TextColumn get companyName => text().named('CompanyName').nullable()();
  TextColumn get profileImage => text().named('ProfileImage').nullable()();

  RealColumn get dr => real().named('DR').nullable()();
  RealColumn get cr => real().named('CR').nullable()();

  TextColumn get currencyStatus => text().named('CurrencyStatus').nullable()();
  IntColumn get companyId => integer().named('CompanyID').nullable()();

  TextColumn get wName => text().named('WName').nullable()();

  @override
  Set<Column> get primaryKey => {accId};
}

/// ========================================================
/// ACC TYPE (SQL: AccType)
/// ========================================================
class AccType extends Table {
  @override
  String get tableName => 'AccType';

  IntColumn get accTypeId =>
      integer().named('AccTypeID').nullable()();

  TextColumn get accTypeName =>
      text().named('AccTypeName').nullable()();

  TextColumn get accTypeNameU =>
      text().named('AccTypeNameu').nullable()();

  TextColumn get flag => text().named('FLAG').nullable()();

  @override
  Set<Column> get primaryKey => {accTypeId};
}

/// ========================================================
/// COMPANY (SQL: Company)
/// ========================================================
class CompanyTable extends Table {
  @override
  String get tableName => 'Company';

  IntColumn get companyId =>
      integer().named('CompanyID').nullable()();

  TextColumn get companyName =>
      text().named('CompanyName').nullable()();

  TextColumn get remarks =>
      text().named('Remarks').nullable()();

  @override
  Set<Column> get primaryKey => {companyId};
}

/// ========================================================
/// DB INFO (SQL: Db_Info)
/// ========================================================
class DbInfoTable extends Table {
  @override
  String get tableName => 'Db_Info';

  TextColumn get emailAddress =>
      text().named('email_address').nullable()();

  TextColumn get databaseName =>
      text().named('database_name').nullable()();
}

/// ========================================================
/// TRANSACTIONS (SQL: Transactions_P)
/// ========================================================
/// This table has *no primary key* in SQLite.
/// We generate an artificial rowId for Drift.
class TransactionsP extends Table {
  @override
  String get tableName => 'Transactions_P';

  /// SQLite has no PK → generate one
  IntColumn get rowId => integer().autoIncrement()();

  IntColumn get voucherNo =>
      integer().named('VoucherNo').nullable()();

  TextColumn get tdate =>
      text().named('TDate').nullable()();

  IntColumn get accId =>
      integer().named('AccID').nullable()();

  IntColumn get accTypeId =>
      integer().named('AccTypeID').nullable()();

  /// SQL COLUMN: Description (NOT Narr)
  TextColumn get description =>
      text().named('Description').nullable()();

  RealColumn get dr =>
      real().named('Dr').nullable()();

  RealColumn get cr =>
      real().named('Cr').nullable()();

  TextColumn get status =>
      text().named('Status').nullable()();

  TextColumn get st =>
      text().named('st').nullable()();

  TextColumn get updateStatus =>
      text().named('updatestatus').nullable()();

  TextColumn get currencyStatus =>
      text().named('currencystatus').nullable()();

  TextColumn get cashStatus =>
      text().named('cashstatus').nullable()();

  IntColumn get userId =>
      integer().named('UserID').nullable()();

  IntColumn get companyId =>
      integer().named('CompanyID').nullable()();

  TextColumn get wName =>
      text().named('WName').nullable()();

  TextColumn get msgNo =>
      text().named('msgno').nullable()();

  TextColumn get hwls1 =>
      text().named('hwls1').nullable()();

  TextColumn get hwls =>
      text().named('hwls').nullable()();

  TextColumn get advanceMess =>
      text().named('advancemess').nullable()();

  /// BIT → stored as INTEGER (0/1)
  IntColumn get cbal =>
      integer().named('cbal').nullable()();

  IntColumn get cbal1 =>
      integer().named('cbal1').nullable()();

  TextColumn get tTime =>
      text().named('TTIME').nullable()();

  TextColumn get pd =>
      text().named('PD').nullable()();

  TextColumn get msgNo2 =>
      text().named('msgno2').nullable()();

  TextColumn get others =>
      text().named('OTHERS').nullable()();
}
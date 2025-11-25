// lib/data/profile/profile_repository.dart

import 'package:drift/drift.dart';

import '../data/local/app_database.dart';


class ProfileRepository {
  final AppDatabase db;

  ProfileRepository(this.db);

  /// ----------------------------------------------------------------------
  /// 1) GET ALL COMPANIES FOR THE LOGGED-IN USER (email-based)
  /// ----------------------------------------------------------------------
  Future<List<CompanyRow>> getCompaniesForUser(String email) async {
    // Query:
    // SELECT DISTINCT c.*
    // FROM Acc_Personal ap
    // JOIN Company c ON ap.CompanyID = c.CompanyID
    // WHERE ap.Email = :email

    final query = db.customSelect(
      '''
      SELECT DISTINCT c.CompanyID, c.CompanyName, c.Remarks
      FROM Acc_Personal ap
      JOIN Company c ON ap.CompanyID = c.CompanyID
      WHERE ap.Email = ?
      ''',
      variables: [Variable(email)],
      readsFrom: {db.companyTable, db.accPersonal},
    );

    return query.map((row) {
      return CompanyRow(
        companyId: row.read<int?>('CompanyID'),
        companyName: row.read<String?>('CompanyName'),
        remarks: row.read<String?>('Remarks'),
      );
    }).get();
  }

  /// ----------------------------------------------------------------------
  /// 2) GET DB INFO FROM Db_Info TABLE (email validation)
  /// ----------------------------------------------------------------------
  Future<DbInfoRow?> getDbInfo() async {
    final query = db.customSelect(
      '''
      SELECT email_address, database_name
      FROM Db_Info
      LIMIT 1
      ''',
      readsFrom: {db.dbInfoTable},
    );

    final result = await query.get();

    if (result.isEmpty) return null;

    final row = result.first;

    return DbInfoRow(
      emailAddress: row.read<String?>('email_address'),
      databaseName: row.read<String?>('database_name'),
    );
  }
}

/// =======================================================================
/// DATA MODELS (clean POJO classes for viewmodel use)
/// =======================================================================

class CompanyRow {
  final int? companyId;
  final String? companyName;
  final String? remarks;

  CompanyRow({
    required this.companyId,
    required this.companyName,
    required this.remarks,
  });
}

class DbInfoRow {
  final String? emailAddress;
  final String? databaseName;

  DbInfoRow({
    required this.emailAddress,
    required this.databaseName,
  });
}
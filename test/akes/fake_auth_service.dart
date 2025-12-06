
import 'package:mehfooz_accounts_app/model/user_model.dart';
import 'package:mehfooz_accounts_app/services/auth_service.dart';

/// A test version of AuthService that returns fixed values.
/// You control the output by setting FakeAuthService.fakeUser.
class FakeAuthService extends AuthService {
  static UserModel? fakeUser;

  @override
  Future<UserModel?> loginWithGoogle() async {
    return fakeUser;
  }
}
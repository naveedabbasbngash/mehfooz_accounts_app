import 'package:flutter_test/flutter_test.dart';
import 'package:mehfooz_accounts_app/model/user_model.dart';
import 'package:mehfooz_accounts_app/viewmodel/auth/auth_view_model.dart';

class FakeAuthService {
  static UserModel? fakeResult;

  static Future<UserModel?> fakeLogin() async {
    return fakeResult;
  }
}

void main() {
  test("Login rejected shows error message", () async {
    // Fake API result
    FakeAuthService.fakeResult = UserModel(
      status: false,
      message: "Account Disabled",
      id: "",
      email: "test@gmail.com",
      firstName: "",
      lastName: "",
      fullName: "",
      imageUrl: "",
      isLogin: 0,
    );

    // Inject fake login function
    final vm = AuthViewModel(
      loginFn: FakeAuthService.fakeLogin,
    );

    // Call the actual method (not login(), but loginWithGoogle())
    final user = await vm.loginWithGoogle();

    // Expectations
    expect(user, isNotNull);
    expect(user!.status, false);
    expect(vm.errorMessage, "Account Disabled");
  });
}
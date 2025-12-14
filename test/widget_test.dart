import 'package:flutter_test/flutter_test.dart';
import 'package:mehfooz_accounts_app/model/user_model.dart';
import 'package:mehfooz_accounts_app/viewmodel/auth/auth_view_model.dart';

import 'auth_view_model_test.dart'; // This is where FakeAuthService is defined

void main() {
  test("Login rejected shows error message", () async {
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

    final vm = AuthViewModel(
      loginFn: FakeAuthService.fakeLogin, // 👈 inject fake login
    );

    // 👇 use the real method name from AuthViewModel
    final user = await vm.loginWithGoogle();

    expect(user!.status, false);
    expect(vm.errorMessage, "Account Disabled");
  });
}
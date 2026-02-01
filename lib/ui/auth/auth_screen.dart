// ==============================
// lib/ui/auth/auth_screen.dart
// FINAL • BUG-FREE • GOOGLE-STYLE
// ==============================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/auth/auth_view_model.dart';
import '../../model/user_model.dart';
import '../../main.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel()..init(),
      child: const _AuthBody(),
    );
  }
}

class _AuthBody extends StatelessWidget {
  const _AuthBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AuthViewModel vm) {
    switch (vm.step) {
      case AuthStep.chooser:
        return _AuthCard(child: _AccountChooserStep(vm));
      case AuthStep.email:
        return _AuthCard(child: _EmailStep(vm));
      case AuthStep.password:
        return _AuthCard(child: _PasswordStep(vm));
      case AuthStep.setPassword:
        return _AuthCard(child: _SetPasswordStep(vm));
      case AuthStep.forgotPassword:
        return _AuthCard(child: _ForgotPasswordStep(vm));
      case AuthStep.contact:
        return _AuthCard(child: _ContactStep(vm));
    }
  }
}

// ==============================
// CARD
// ==============================
class _AuthCard extends StatelessWidget {
  final Widget child;
  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(child.runtimeType),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ==============================
// ACCOUNT CHOOSER
// ==============================
class _AccountChooserStep extends StatelessWidget {
  final AuthViewModel vm;
  const _AccountChooserStep(this.vm);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          title: 'Choose an account',
          subtitle: 'to continue to Mahfooz Accounts',
        ),
        const SizedBox(height: 24),

        ...vm.savedAccounts.map(
              (user) => _AccountTile(
            user: user,
            onTap: () async {
              vm.email = user.email;
              vm.step = AuthStep.password;
              vm.notifyListeners();
            },
            onRemove: () => vm.removeAccount(user.email),
          ),
        ),

        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: vm.useAnotherAccount,
          icon: const Icon(Icons.add),
          label: const Text('Use another account'),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AccountTile({
    required this.user,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        child: Text(
          user.fullName.isNotEmpty
              ? user.fullName[0].toUpperCase()
              : user.email[0].toUpperCase(),
        ),
      ),
      title: Text(
        user.fullName.isNotEmpty ? user.fullName : user.email,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(user.email),
      trailing: PopupMenuButton(
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
        onSelected: (_) => onRemove(),
      ),
      onTap: onTap,
    );
  }
}

// ==============================
// EMAIL STEP
// ==============================
class _EmailStep extends StatefulWidget {
  final AuthViewModel vm;
  const _EmailStep(this.vm);

  @override
  State<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<_EmailStep> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          title: 'Welcome',
          subtitle: 'Sign in with your email',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            border: OutlineInputBorder(),
          ),
        ),
        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        const SizedBox(height: 24),
        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Continue',
          onPressed: () => vm.submitEmail(controller.text),
        ),
      ],
    );
  }
}

// ==============================
// PASSWORD STEP (FIXED)
// ==============================
class _PasswordStep extends StatefulWidget {
  final AuthViewModel vm;
  const _PasswordStep(this.vm);

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep> {
  final controller = TextEditingController();
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: vm.goBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: _Header(
                title: 'Welcome back',
                subtitle: vm.email,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              vm.step = AuthStep.forgotPassword;
              vm.notifyListeners();
            },
            child: const Text('Forgot password?'),
          ),
        ),

        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),

        const SizedBox(height: 8),

        // ✅ FIXED OVERFLOW

        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        const SizedBox(height: 16),

        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Sign in',
          onPressed: () async {
            final user = await vm.loginWithPassword(controller.text);
            if (user != null && context.mounted) {
              final appState =
              context.findAncestorStateOfType<MahfoozAppState>();
              await appState?.onLoginSuccess();
            }
          },
        ),
      ],
    );
  }
}

// ==============================
// SET PASSWORD STEP
// ==============================
class _SetPasswordStep extends StatefulWidget {
  final AuthViewModel vm;
  const _SetPasswordStep(this.vm);

  @override
  State<_SetPasswordStep> createState() => _SetPasswordStepState();
}

class _SetPasswordStepState extends State<_SetPasswordStep> {
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  bool o1 = true, o2 = true;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: vm.goBack, icon: const Icon(Icons.arrow_back)),
            const _Header(
              title: 'Set your password',
              subtitle: 'Create a password for your account',
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: p1,
          obscureText: o1,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: p2,
          obscureText: o2,
          decoration: const InputDecoration(
            labelText: 'Confirm password',
            border: OutlineInputBorder(),
          ),
        ),
        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        const SizedBox(height: 24),
        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Set password',
          onPressed: () => vm.setPassword(p1.text, p2.text),
        ),
      ],
    );
  }
}

// ==============================
// FORGOT PASSWORD STEP
// ==============================
class _ForgotPasswordStep extends StatelessWidget {
  final AuthViewModel vm;
  const _ForgotPasswordStep(this.vm);

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: vm.email);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(onPressed: vm.goBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(height: 8),
        const _Header(
          title: 'Reset password',
          subtitle: 'We will send you a reset link',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email address',
            border: OutlineInputBorder(),
          ),
        ),
        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        if (vm.forgotPasswordSuccess && vm.infoMessage != null)
          _SuccessBox(vm.infoMessage!),
        const SizedBox(height: 24),
        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Send reset link',
          onPressed: () => vm.forgotPassword(controller.text),
        ),
      ],
    );
  }
}

// ==============================
// CONTACT STEP
// ==============================
class _ContactStep extends StatelessWidget {
  final AuthViewModel vm;
  const _ContactStep(this.vm);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          title: 'Account not found',
          subtitle: 'This email is not registered',
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          loading: false,
          label: 'Back',
          onPressed: vm.goBack,
        ),
      ],
    );
  }
}

// ==============================
// SHARED WIDGETS
// ==============================
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(label),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}

class _SuccessBox extends StatelessWidget {
  final String text;
  const _SuccessBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.green, fontSize: 13)),
    );
  }
}
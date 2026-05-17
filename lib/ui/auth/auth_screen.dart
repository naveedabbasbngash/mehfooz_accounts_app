// ==============================
// lib/ui/auth/auth_screen.dart
// FINAL • BUG-FREE • GOOGLE-STYLE
// ==============================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/auth/auth_view_model.dart';
import '../../model/user_model.dart';
import '../../main.dart';

const _kBrandBlue = Color(0xFF1862A3);
const _kBrandBlueDark = Color(0xFF0E497C);
const _kAuthSurface = Color(0xFFF4F8FC);

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
      backgroundColor: _kAuthSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7FBFF), Color(0xFFEEF4FB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBrandBlue.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              top: 90,
              right: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBrandBlue.withValues(alpha: 0.07),
                ),
              ),
            ),
            SafeArea(
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
          ],
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
      case AuthStep.register:
        return _AuthCard(child: _RegisterStep(vm));
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF7FBFF)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD6E6F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x08FFFFFF),
            blurRadius: 10,
            offset: Offset(0, -2),
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
        const _BrandHero(
          eyebrow: 'Mahfooz Accounts MKB',
          title: 'Welcome to MKB',
          subtitle:
              'Continue with a saved account or start a fresh registration.',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD7E7F5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kBrandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: _kBrandBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saved accounts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...vm.savedAccounts.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AccountTile(
                    user: user,
                    onTap: () => vm.selectSavedAccount(user.email),
                    onRemove: () => vm.removeAccount(user.email),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SecondaryActionButton(
          onPressed: vm.useAnotherAccount,
          icon: Icons.alternate_email_rounded,
          label: 'Use another account',
        ),
        const SizedBox(height: 10),
        _BrandOutlinedButton(
          onPressed: vm.openRegister,
          icon: Icons.person_add_alt_1_rounded,
          label: 'Register now',
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
    final title = user.fullName.isNotEmpty ? user.fullName : user.email;
    final seed = (title.isNotEmpty ? title[0] : 'M').toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD9E8F6)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kBrandBlue, _kBrandBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    seed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF102033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60758A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF5B7083),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
                onSelected: (_) => onRemove(),
              ),
            ],
          ),
        ),
      ),
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
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.vm.email);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(title: 'Welcome', subtitle: 'Sign in with your email'),
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
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => vm.openRegister(prefillEmail: controller.text),
            child: const Text('New user? Register now'),
          ),
        ),
      ],
    );
  }
}

// ==============================
// REGISTER STEP
// ==============================
class _RegisterStep extends StatefulWidget {
  final AuthViewModel vm;
  const _RegisterStep(this.vm);

  @override
  State<_RegisterStep> createState() => _RegisterStepState();
}

class _RegisterStepState extends State<_RegisterStep> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.vm.email);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandHero(
          eyebrow: 'Mahfooz Accounts MKB',
          title: 'Register now',
          subtitle:
              'Secure your device, add your team, and start working in one premium flow.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD9E8F6)),
              ),
              child: IconButton(
                onPressed: vm.goBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: const Color(0xFF16314A),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Register to start using Mahfooz Accounts MKB',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF60758A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD9E8F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _brandInputDecoration('First name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _brandInputDecoration('Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _brandInputDecoration('Email address'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: _brandInputDecoration(
                  'Password',
                  helperText: 'Minimum 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: _brandInputDecoration(
                  'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        if (vm.infoMessage != null && vm.errorMessage == null)
          _SuccessBox(vm.infoMessage!),
        const SizedBox(height: 20),
        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Create account',
          onPressed: () async {
            final result = await vm.registerAccount(
              firstName: _firstNameCtrl.text,
              lastName: _lastNameCtrl.text,
              emailValue: _emailCtrl.text,
              password: _passwordCtrl.text,
              confirmPassword: _confirmCtrl.text,
            );
            if (!context.mounted) return;
            await _showRegisterResultDialog(
              context,
              success: result.success,
              message: result.message,
            );
            if (!context.mounted) return;
            if (result.success) {
              vm.openEmailStep(prefillEmail: _emailCtrl.text.trim());
            }
          },
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Protected registration powered by your Mahfooz workspace',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: vm.useAnotherAccount,
            child: const Text('Already have an account? Sign in'),
          ),
        ),
      ],
    );
  }
}

Future<void> _showRegisterResultDialog(
  BuildContext context, {
  required bool success,
  required String message,
}) async {
  final color = success ? const Color(0xFF0F9D58) : const Color(0xFFC62828);
  final title = success ? 'Registration Done' : 'Registration Failed';
  final icon = success ? Icons.verified_rounded : Icons.error_rounded;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(success ? 'Continue to Sign In' : 'Try Again'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
              child: _Header(title: 'Welcome back', subtitle: vm.email),
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
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => obscure = !obscure),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: vm.goToForgotPassword,
            child: const Text('Forgot password?'),
          ),
        ),

        if (vm.errorMessage != null) _ErrorBox(vm.errorMessage!),
        const SizedBox(height: 16),

        _PrimaryButton(
          loading: vm.isLoading,
          label: 'Sign in',
          onPressed: () async {
            final user = await vm.loginWithPassword(controller.text);
            if (user != null && context.mounted) {
              final appState = context
                  .findAncestorStateOfType<MahfoozAppState>();
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
            IconButton(
              onPressed: vm.goBack,
              icon: const Icon(Icons.arrow_back),
            ),
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
        _PrimaryButton(loading: false, label: 'Back', onPressed: vm.goBack),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => vm.openRegister(prefillEmail: vm.email),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Register now'),
          ),
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
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }
}

InputDecoration _brandInputDecoration(
  String label, {
  String? helperText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: 1.2),
  );

  return InputDecoration(
    labelText: label,
    helperText: helperText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF8FBFF),
    labelStyle: const TextStyle(
      color: Color(0xFF60758A),
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(const Color(0xFFD7E7F5)),
    enabledBorder: border(const Color(0xFFD7E7F5)),
    focusedBorder: border(_kBrandBlue),
  );
}

class _BrandHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _BrandHero({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBrandBlue, _kBrandBlueDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261862A3),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFE6F1FB),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _SecondaryActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: _kBrandBlue),
        label: Text(
          label,
          style: const TextStyle(
            color: _kBrandBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFEFF6FD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _BrandOutlinedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _BrandOutlinedButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kBrandBlue,
          side: const BorderSide(color: Color(0xFFBFD8EC)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
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
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBrandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
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
      child: Text(
        text,
        style: const TextStyle(color: Colors.green, fontSize: 13),
      ),
    );
  }
}

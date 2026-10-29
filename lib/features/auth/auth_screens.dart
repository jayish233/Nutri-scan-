import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/common.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Sign-in and onboarding are always dark.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.showBack = true});

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Theme(
    data: buildTheme(Brightness.dark, Theme.of(context).platform),
    child: Scaffold(
      backgroundColor: AppColors.dark.canvas,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(spaceXl, spaceS, spaceXl, spaceXl), child: child),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: spaceXl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
        const SizedBox(height: spaceS),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 17)),
      ],
    ),
  );
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: spaceM),
          child: Semantics(
            liveRegion: true,
            child: Text(message!, style: const TextStyle(color: AppColors.errorText, fontSize: 15)),
          ),
        );
}

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final error = state is Booting ? state.error : null;
    return Scaffold(
      backgroundColor: AppColors.dark.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoMark(),
            const SizedBox(height: spaceL),
            const Wordmark(),
            if (error != null) ...[
              const SizedBox(height: spaceXl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceXl),
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(onPressed: () => ref.read(sessionProvider.notifier).boot(), child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget value(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: spaceM),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand, size: 22),
          const SizedBox(width: spaceM),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
    return AuthScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: spaceXxl),
          const LogoMark(size: 72),
          const SizedBox(height: spaceL),
          const Wordmark(),
          const SizedBox(height: spaceXxl * 2),
          Text("Snap your plate. Know what's in it.", style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: spaceM),
          const Text(
            'Photo-first nutrition tracking with editable estimates and private streaks.',
            style: TextStyle(color: AppColors.muted, fontSize: 17),
          ),
          const SizedBox(height: spaceXl),
          value(Icons.photo_camera, 'One photo becomes calories and macros'),
          value(Icons.eco, 'Protein ideas that fit how you eat'),
          value(Icons.lock, 'Share streaks only, never calories or weight'),
          const SizedBox(height: spaceXl),
          PrimaryButton(label: 'Sign in', onPressed: () => context.push('/sign-in')),
          const SizedBox(height: spaceM),
          SecondaryButton(label: 'Create account', frosted: true, onPressed: () => context.push('/register')),
        ],
      ),
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _valid => _emailRe.hasMatch(_email.text.trim()) && _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_email.text, _password.text);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final expired = session is SignedOut ? session.message : null;
    final ios = isCupertino(context);
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                const Positioned.fill(child: ScanBrackets()),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: spaceXl),
                  child: Column(
                    children: [
                      const LogoMark(size: 72),
                      const SizedBox(height: spaceL),
                      Semantics(header: true, child: Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium)),
                      const SizedBox(height: spaceS),
                      const Text(
                        'Sign in to keep your streak going.',
                        style: TextStyle(color: AppColors.muted, fontSize: 17),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: spaceS),
            _FormError(_error ?? expired),
            AuthField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
            ),
            // No 8-character rule here so older passwords still work.
            AuthField(
              controller: _password,
              label: 'Password',
              obscure: true,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?')),
            ),
            const SizedBox(height: spaceS),
            PrimaryButton(label: 'Sign in', loading: _loading, onPressed: _valid ? _submit : null),
            if (ios)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: spaceL),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: spaceM),
                      child: Text('or', style: TextStyle(color: AppColors.muted)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              )
            else
              const SizedBox(height: spaceM),
            SecondaryButton(label: 'Join with an invite', frosted: true, onPressed: () => context.pushReplacement('/register')),
            const SizedBox(height: spaceXl),
            // Access is gated by an email invite list on the server, not by a code.
            const Text(
              'NutriScan is invite-only. Ask a friend to add your email.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _loading = false, _touched = false;
  String? _error;
  Map<String, String> _serverFields = {};

  Map<String, String> get _localErrors => {
    if (_name.text.trim().length < 2) 'display_name': 'Enter at least 2 characters.',
    if (!_emailRe.hasMatch(_email.text.trim())) 'email': 'Enter a valid email address.',
    if (_password.text.length < 8) 'password': 'Use at least 8 characters.',
    if (_confirm.text != _password.text) 'confirm': 'Passwords do not match.',
  };

  String? _err(String field) => _serverFields[field] ?? (_touched ? _localErrors[field] : null);

  Future<void> _submit() async {
    setState(() {
      _touched = true;
      _error = null;
      _serverFields = {};
    });
    if (_localErrors.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).register(name: _name.text, email: _email.text, password: _password.text);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.kind) {
          case ApiErrorKind.conflict:
            _serverFields = {'email': 'An account with that email already exists.'};
          case ApiErrorKind.validation when e.fields.isNotEmpty:
            _serverFields = {for (final k in e.fields.keys) k: e.message};
          default:
            _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Create your account.', 'Two minutes now, then just point your camera at a plate.'),
          _FormError(_error),
          AuthField(
            controller: _name,
            label: 'Display name',
            error: _err('display_name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => setState(() {}),
          ),
          AuthField(
            controller: _email,
            label: 'Email',
            error: _err('email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() => _serverFields.remove('email')),
          ),
          AuthField(
            controller: _password,
            label: 'Password',
            obscure: true,
            error: _err('password'),
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() => _serverFields.remove('password')),
          ),
          AuthField(
            controller: _confirm,
            label: 'Confirm password',
            obscure: true,
            error: _err('confirm'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: spaceS),
          PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
        ],
      ),
    ),
  );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).forgotPassword(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("If that email has an account, we've sent a reset link.")));
      context.go('/sign-in');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Title('Forgot password?', "Enter your email and we'll send you a reset link."),
        _FormError(_error),
        AuthField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
        PrimaryButton(label: 'Send link', loading: _loading, onPressed: _emailRe.hasMatch(_email.text.trim()) ? _submit : null),
      ],
    ),
  );
}

// Password reset is an emailed Better Auth link now; the old 6-digit code screen is gone.

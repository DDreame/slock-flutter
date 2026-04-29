import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/login_controller.dart';
import 'package:slock_app/l10n/l10n.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const ValueKey('login-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('login-email'),
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.loginEmailLabel),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('login-password'),
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: l10n.loginPasswordLabel,
                  suffixIcon: IconButton(
                    key: const ValueKey('login-password-toggle'),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('login-submit'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.loginSubmitLabel),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/register'),
                child: Text(l10n.loginCreateAccountCta),
              ),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: Text(l10n.loginForgotPasswordCta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = context.l10n;

    if (email.isEmpty) {
      setState(() => _errorText = l10n.loginEmailRequiredError);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorText = l10n.loginEmailInvalidError);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = l10n.loginPasswordRequiredError);
      return;
    }

    setState(() => _errorText = null);

    await ref.read(loginControllerProvider.notifier).submit(
          email: email,
          password: password,
        );

    final state = ref.read(loginControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _errorText = error is AppFailure
            ? (error.message ?? l10n.loginFailedFallback)
            : l10n.loginFailedFallback;
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/register_controller.dart';
import 'package:slock_app/l10n/l10n.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const ValueKey('register-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('register-display-name'),
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: l10n.registerDisplayNameLabel,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('register-email'),
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.registerEmailLabel),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('register-password'),
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: l10n.registerPasswordLabel,
                  suffixIcon: IconButton(
                    key: const ValueKey('register-password-toggle'),
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
                key: const ValueKey('register-submit'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.registerSubmitLabel),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.registerAlreadyHaveAccountCta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = context.l10n;

    if (displayName.isEmpty) {
      setState(() => _errorText = l10n.registerDisplayNameRequiredError);
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorText = l10n.registerEmailRequiredError);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorText = l10n.registerEmailInvalidError);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = l10n.loginPasswordRequiredError);
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = l10n.registerPasswordTooShortError);
      return;
    }

    setState(() => _errorText = null);

    await ref.read(registerControllerProvider.notifier).submit(
          email: email,
          password: password,
          displayName: displayName,
        );

    final state = ref.read(registerControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _errorText = error is AppFailure
            ? (error.message ?? l10n.registerFailedFallback)
            : l10n.registerFailedFallback;
      });
    }
  }
}

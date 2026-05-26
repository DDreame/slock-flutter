import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/reset_password_controller.dart';
import 'package:slock_app/l10n/l10n.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorText;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final l10n = context.l10n;

    if (_completed) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.resetPasswordTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.resetPasswordCompletedMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.resetPasswordBackToLogin),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const ValueKey('reset-password-error'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('reset-password-input'),
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: l10n.resetPasswordNewPasswordLabel,
                  suffixIcon: IconButton(
                    key: const ValueKey('reset-password-toggle'),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    tooltip: l10n.togglePasswordVisibilityTooltip,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('reset-password-confirm-input'),
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: l10n.resetPasswordConfirmPasswordLabel,
                  suffixIcon: IconButton(
                    key: const ValueKey('reset-password-confirm-toggle'),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    tooltip: l10n.togglePasswordVisibilityTooltip,
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('reset-password-submit'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.resetPasswordSubmitLabel),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.resetPasswordBackToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final token = widget.token?.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorText = l10n.resetPasswordLinkInvalidError;
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _errorText = l10n.resetPasswordTooShortError;
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _errorText = l10n.resetPasswordMismatchError;
      });
      return;
    }

    setState(() {
      _errorText = null;
    });

    await ref.read(resetPasswordControllerProvider.notifier).submit(
          token: token,
          password: password,
        );
    if (!mounted) return;

    // Check controller state after submit — only mark complete on success.
    // submit() no longer rethrows, so we inspect the resulting state (#720).
    final result = ref.read(resetPasswordControllerProvider);
    if (result is AsyncError) {
      final error = result.error;
      setState(() {
        _errorText = error is AppFailure
            ? error.userMessage(context.l10n)
            : context.l10n.errorUnknown;
      });
    } else {
      setState(() {
        _completed = true;
      });
    }
  }
}

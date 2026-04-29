import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/reset_password_controller.dart';

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

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);

    if (_completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset Password')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Password reset complete. You can now sign in with your new password.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('reset-password-confirm-input'),
              controller: _confirmPasswordController,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              obscureText: true,
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
                  : const Text('Set new password'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final token = widget.token?.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorText = 'Reset link is missing or invalid.';
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _errorText = 'Password must be at least 8 characters.';
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _errorText = null;
    });

    try {
      await ref.read(resetPasswordControllerProvider.notifier).submit(
            token: token,
            password: password,
          );
      if (!mounted) return;
      setState(() {
        _completed = true;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorText = failure.message ??
            'Password reset failed. The link may be expired.';
      });
    }
  }
}

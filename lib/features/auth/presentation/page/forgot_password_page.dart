import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/forgot_password_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  String? _errorText;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_submitted) ...[
                Container(
                  key: const ValueKey('forgot-password-success'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Check your email',
                        key: const ValueKey('forgot-password-success-title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If that email is registered, a reset link has been sent. Check your inbox.',
                        key: const ValueKey(
                          'forgot-password-success-message',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const ValueKey('forgot-password-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('forgot-password-email'),
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('forgot-password-submit'),
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Reset Password'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorText = 'Email is required.';
        _submitted = false;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() {
        _errorText = 'Enter a valid email address.';
        _submitted = false;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _submitted = false;
    });

    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(email: email);

    final state = ref.read(forgotPasswordControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _errorText = error is AppFailure
            ? (error.message ?? 'Failed to send reset email. Please try again.')
            : 'Failed to send reset email. Please try again.';
      });
    } else {
      setState(() => _submitted = true);
    }
  }
}

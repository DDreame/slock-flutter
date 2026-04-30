import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/forgot_password_controller.dart';
import 'package:slock_app/l10n/l10n.dart';

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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
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
                        l10n.forgotPasswordSuccessTitle,
                        key: const ValueKey('forgot-password-success-title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.forgotPasswordSuccessMessage,
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
                decoration:
                    InputDecoration(labelText: l10n.forgotPasswordEmailLabel),
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
                    : Text(l10n.forgotPasswordSubmitLabel),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.forgotPasswordBackToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorText = l10n.forgotPasswordEmailRequiredError;
        _submitted = false;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() {
        _errorText = l10n.forgotPasswordEmailInvalidError;
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
            ? (error.message ?? context.l10n.forgotPasswordFailedFallback)
            : context.l10n.forgotPasswordFailedFallback;
      });
    } else {
      setState(() => _submitted = true);
    }
  }
}

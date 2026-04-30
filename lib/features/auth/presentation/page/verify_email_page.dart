import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/verify_email_controller.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _manualTokenController = TextEditingController();
  String? _errorText;
  bool _verified = false;
  bool _resent = false;
  bool _autoSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeVerifyInitialToken();
    });
  }

  @override
  void dispose() {
    _manualTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(verifyEmailControllerProvider);
    final session = ref.watch(sessionStoreProvider);
    final canResend = session.isAuthenticated && session.emailVerified == false;
    final l10n = context.l10n;

    if (_verified) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.verifyEmailTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.verifyEmailSuccessMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: Text(l10n.verifyEmailContinueButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyEmailTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.verifyEmailInstructions,
                textAlign: TextAlign.center,
              ),
              if (_resent) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.verifyEmailResentMessage,
                  key: const ValueKey('verify-email-resent'),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  key: const ValueKey('verify-email-error'),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              if (canResend) ...[
                FilledButton(
                  key: const ValueKey('verify-email-resend'),
                  onPressed:
                      controllerState.isLoading ? null : _resendVerification,
                  child: controllerState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.verifyEmailResendButton),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('verify-email-token'),
                controller: _manualTokenController,
                decoration: InputDecoration(
                  labelText: l10n.verifyEmailTokenLabel,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('verify-email-submit'),
                onPressed:
                    controllerState.isLoading ? null : _submitManualToken,
                child: Text(l10n.verifyEmailSubmitLabel),
              ),
              if (session.isAuthenticated) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      ref.read(sessionStoreProvider.notifier).logout(),
                  child: Text(l10n.verifyEmailSignOut),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.verifyEmailBackToLogin),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _maybeVerifyInitialToken() async {
    if (_autoSubmitted) return;
    final token = widget.initialToken?.trim();
    if (token == null || token.isEmpty) return;
    _autoSubmitted = true;
    await _submitToken(token);
  }

  Future<void> _submitManualToken() async {
    final token = _manualTokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorText = context.l10n.verifyEmailTokenRequiredError;
      });
      return;
    }
    await _submitToken(token);
  }

  Future<void> _submitToken(String token) async {
    setState(() {
      _errorText = null;
      _resent = false;
    });
    try {
      await ref.read(verifyEmailControllerProvider.notifier).submitToken(token);
      if (!mounted) return;
      setState(() {
        _verified = true;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorText = failure.message ?? context.l10n.verifyEmailFailedFallback;
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _errorText = null;
      _resent = false;
    });
    try {
      await ref
          .read(verifyEmailControllerProvider.notifier)
          .resendVerification();
      if (!mounted) return;
      setState(() {
        _resent = true;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorText =
            failure.message ?? context.l10n.verifyEmailResendFailedFallback;
      });
    }
  }
}

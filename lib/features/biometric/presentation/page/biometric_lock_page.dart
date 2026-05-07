import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/auth/biometric_service.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';

/// Full-screen biometric lock overlay.
///
/// Prompts the user for biometric authentication and unlocks on success.
/// Shown via router redirect when the biometric store indicates a locked state.
class BiometricLockPage extends ConsumerStatefulWidget {
  const BiometricLockPage({super.key});

  @override
  ConsumerState<BiometricLockPage> createState() => _BiometricLockPageState();
}

class _BiometricLockPageState extends ConsumerState<BiometricLockPage> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Trigger biometric prompt on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final service = ref.read(biometricServiceProvider);
    final result = await service.authenticate(
      localizedReason: 'Authenticate to continue using Slock',
    );

    if (!mounted) return;

    switch (result) {
      case BiometricAuthResult.success:
        ref.read(biometricStoreProvider.notifier).unlock();
      case BiometricAuthResult.cancelled:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = null;
        });
      case BiometricAuthResult.lockout:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Too many attempts. Please try again later.';
        });
      case BiometricAuthResult.permanentLockout:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Biometrics locked. Please use your device passcode.';
        });
      case BiometricAuthResult.error:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Authentication unavailable.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  key: const ValueKey('biometric-lock-icon'),
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Authenticate to continue',
                  key: const ValueKey('biometric-lock-title'),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify your identity to access Slock',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    key: const ValueKey('biometric-lock-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                if (!_isAuthenticating)
                  FilledButton.icon(
                    key: const ValueKey('biometric-lock-retry'),
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Try again'),
                  ),
                if (_isAuthenticating)
                  const CircularProgressIndicator(
                    key: ValueKey('biometric-lock-progress'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

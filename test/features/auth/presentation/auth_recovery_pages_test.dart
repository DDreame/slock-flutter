import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/auth/presentation/page/reset_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/verify_email_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  testWidgets('ResetPasswordPage submits token and password', (tester) async {
    final repository = _TrackingAuthRepository();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ResetPasswordPage(token: 'reset-token'),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-password-input')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-confirm-input')),
      'new-password',
    );
    await tester.tap(find.byKey(const ValueKey('reset-password-submit')));
    await tester.pumpAndSettle();

    expect(repository.lastResetToken, 'reset-token');
    expect(repository.lastResetPassword, 'new-password');
    expect(
      find.text(
        'Password reset complete. You can now sign in with your new password.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('VerifyEmailPage auto-submits initial token', (tester) async {
    final repository = _TrackingAuthRepository();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VerifyEmailPage(initialToken: 'verify-token'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastVerifyToken, 'verify-token');
    expect(
      find.text('Email verified. You can continue to the app.'),
      findsOneWidget,
    );
  });
}

class _TrackingAuthRepository implements AuthRepository {
  String? lastResetToken;
  String? lastResetPassword;
  String? lastVerifyToken;

  @override
  Future<AuthUser> getMe() async =>
      const AuthUser(id: 'user-1', emailVerified: false);

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resendVerification() async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    lastResetToken = token;
    lastResetPassword = password;
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    lastVerifyToken = token;
  }
}

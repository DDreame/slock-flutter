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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResetPasswordPage(token: 'reset-token'),
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

  // Regression test for #720: controller no longer rethrows, page must check
  // controller state after submit() and stay on form with error on failure.
  testWidgets(
      'ResetPasswordPage stays on form with error when submit fails (#720)',
      (tester) async {
    final repository = _FailingAuthRepository();
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResetPasswordPage(token: 'reset-token'),
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

    // Must NOT show the success/completed UI.
    expect(
      find.text(
        'Password reset complete. You can now sign in with your new password.',
      ),
      findsNothing,
      reason: 'Page must not show completed state on failure',
    );

    // Must show the error text.
    expect(
      find.byKey(const ValueKey('reset-password-error')),
      findsOneWidget,
      reason: 'Page must show error message on failure',
    );

    // Submit button should still be visible (user can retry).
    expect(
      find.byKey(const ValueKey('reset-password-submit')),
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VerifyEmailPage(initialToken: 'verify-token'),
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

/// AuthRepository that always throws on resetPassword — used for #720
/// regression test.
class _FailingAuthRepository implements AuthRepository {
  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    throw Exception('Network timeout');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

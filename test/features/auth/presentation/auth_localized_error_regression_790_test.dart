// =============================================================================
// #790 — Regression: Auth pages show localized errors, not raw backend messages
//
// Proves the previously-missed auth presentation pages (login, register,
// forgot-password) render AppFailure.userMessage(l10n) instead of raw
// AppFailure.message.
//
// Load-bearing proof:
//   Reverting the auth page fixes (restoring `error.message ?? fallback`)
//   causes these tests to fail because:
//   - The raw message assertion (findsNothing) would find the raw text
//   - The localized message assertion (findsOneWidget) would not find it
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/features/auth/presentation/page/forgot_password_page.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

Widget _buildPage(Widget page, {required _FakeAuthRepository repository}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: page,
    ),
  );
}

void main() {
  group('#790 regression — auth pages never leak raw AppFailure.message', () {
    testWidgets(
      'LoginPage: NetworkFailure shows localized network error, not raw message',
      (tester) async {
        const rawMessage = 'Connection reset by peer at tcp://10.0.0.1:443';
        final repo = _FakeAuthRepository(
          loginFailure: const NetworkFailure(message: rawMessage),
        );
        await tester.pumpWidget(
          _buildPage(const LoginPage(), repository: repo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'password123',
        );
        await tester.tap(find.byKey(const ValueKey('login-submit')));
        await tester.pumpAndSettle();

        // Raw backend message must NOT appear in the UI.
        expect(find.text(rawMessage), findsNothing);
        // Localized user-facing message must appear.
        expect(
          find.text(
            'Network error. Please check your connection and try again.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LoginPage: ServerFailure shows localized server error, not raw message',
      (tester) async {
        const rawMessage = 'ECONNREFUSED 127.0.0.1:5432';
        final repo = _FakeAuthRepository(
          loginFailure: const ServerFailure(message: rawMessage),
        );
        await tester.pumpWidget(
          _buildPage(const LoginPage(), repository: repo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'password123',
        );
        await tester.tap(find.byKey(const ValueKey('login-submit')));
        await tester.pumpAndSettle();

        expect(find.text(rawMessage), findsNothing);
        expect(
          find.text('Server error. Please try again later.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RegisterPage: ValidationFailure shows localized validation error',
      (tester) async {
        const rawMessage =
            'email: must be unique; password: bcrypt cost too low';
        final repo = _FakeAuthRepository(
          registerFailure: const ValidationFailure(message: rawMessage),
        );
        await tester.pumpWidget(
          _buildPage(const RegisterPage(), repository: repo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('register-display-name')),
          'Alice',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register-email')),
          'alice@example.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register-password')),
          'securepassword',
        );
        await tester.tap(find.byKey(const ValueKey('register-submit')));
        await tester.pumpAndSettle();

        expect(find.text(rawMessage), findsNothing);
        expect(
          find.text('Invalid input. Please check and try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ForgotPasswordPage: TimeoutFailure shows localized timeout error',
      (tester) async {
        const rawMessage = 'DioException [receiveTimeout]: 30000ms exceeded';
        final repo = _FakeAuthRepository(
          forgotPasswordFailure: const TimeoutFailure(message: rawMessage),
        );
        await tester.pumpWidget(
          _buildPage(const ForgotPasswordPage(), repository: repo),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-email')),
          'user@example.com',
        );
        await tester.tap(find.byKey(const ValueKey('forgot-password-submit')));
        await tester.pumpAndSettle();

        expect(find.text(rawMessage), findsNothing);
        expect(
          find.text('Request timed out. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.loginFailure,
    this.registerFailure,
    this.forgotPasswordFailure,
  });

  final AppFailure? loginFailure;
  final AppFailure? registerFailure;
  final AppFailure? forgotPasswordFailure;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (loginFailure != null) throw loginFailure!;
    return const AuthResult(accessToken: 'token', refreshToken: 'refresh');
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (registerFailure != null) throw registerFailure!;
    return const AuthResult(accessToken: 'token', refreshToken: 'refresh');
  }

  @override
  Future<AuthUser> getMe() async =>
      const AuthUser(id: 'user-1', emailVerified: false);

  @override
  Future<void> requestPasswordReset({required String email}) async {
    if (forgotPasswordFailure != null) throw forgotPasswordFailure!;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> verifyEmail({required String token}) async {}

  @override
  Future<void> resendVerification() async {}
}

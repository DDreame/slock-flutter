import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/auth/presentation/page/forgot_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/features/auth/presentation/page/reset_password_page.dart';
import 'package:slock_app/features/auth/presentation/page/verify_email_page.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

Widget _buildPage(
  Widget page, {
  required _FakeAuthRepository repository,
  Locale? locale,
}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
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
  group('LoginPage', () {
    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(const LoginPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-error')), findsOneWidget);
    });

    testWidgets('shows error when email is invalid', (tester) async {
      await tester.pumpWidget(
        _buildPage(const LoginPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(const LoginPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'user@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('shows API error on login failure', (tester) async {
      final repo = _FakeAuthRepository(
        loginFailure: const UnauthorizedFailure(message: 'Invalid credentials'),
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
        'wrongpassword',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(
        _buildPage(const LoginPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(
        find.byKey(const ValueKey('login-password')),
      );
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('login-password-toggle')));
      await tester.pumpAndSettle();

      final updatedField = tester.widget<TextField>(
        find.byKey(const ValueKey('login-password')),
      );
      expect(updatedField.obscureText, isFalse);
    });

    testWidgets('body is scrollable for keyboard safety', (tester) async {
      await tester.pumpWidget(
        _buildPage(const LoginPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('valid input passes validation and reaches submit',
        (tester) async {
      final repo = _FakeAuthRepository();
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
        'validpassword',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login-error')), findsNothing);
      expect(repo.loginEmails, ['user@example.com']);
    });

    testWidgets('uses localized Spanish copy when locale changes',
        (tester) async {
      await tester.pumpWidget(
        _buildPage(
          const LoginPage(),
          repository: _FakeAuthRepository(),
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesion'), findsWidgets);
      expect(find.text('Correo electronico'), findsOneWidget);
      expect(find.text('Olvidaste tu contrasena?'), findsOneWidget);
    });
  });

  group('RegisterPage', () {
    testWidgets('shows error when display name is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Display name is required.'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('register-display-name')),
        'Alice',
      );
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('shows error when password is too short', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
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
        'short',
      );
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(
          find.text('Password must be at least 8 characters.'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
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
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('shows API error on registration failure', (tester) async {
      final repo = _FakeAuthRepository(
        registerFailure:
            const ServerFailure(message: 'Email already registered'),
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
        'longpassword123',
      );
      await tester.tap(find.byKey(const ValueKey('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email already registered'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(
        find.byKey(const ValueKey('register-password')),
      );
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('register-password-toggle')));
      await tester.pumpAndSettle();

      final updatedField = tester.widget<TextField>(
        find.byKey(const ValueKey('register-password')),
      );
      expect(updatedField.obscureText, isFalse);
    });

    testWidgets('body is scrollable for keyboard safety', (tester) async {
      await tester.pumpWidget(
        _buildPage(const RegisterPage(), repository: _FakeAuthRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('valid input passes validation and reaches submit',
        (tester) async {
      final repo = _FakeAuthRepository();
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

      expect(find.byKey(const ValueKey('register-error')), findsNothing);
      expect(repo.registerEmails, ['alice@example.com']);
    });
  });

  group('ForgotPasswordPage', () {
    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(
        _buildPage(
          const ForgotPasswordPage(),
          repository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('forgot-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
    });

    testWidgets('shows error when email is invalid', (tester) async {
      await tester.pumpWidget(
        _buildPage(
          const ForgotPasswordPage(),
          repository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot-password-email')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const ValueKey('forgot-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows success confirmation after submit', (tester) async {
      await tester.pumpWidget(
        _buildPage(
          const ForgotPasswordPage(),
          repository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot-password-email')),
        'user@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('forgot-password-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forgot-password-success')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forgot-password-success-title')),
        findsOneWidget,
      );
      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('forgot-password-success-message')),
        findsOneWidget,
      );
      expect(
        find.text(
          'If that email is registered, a reset link has been sent. Check your inbox.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows API error on failure', (tester) async {
      final repo = _FakeAuthRepository(
        forgotPasswordFailure: const NetworkFailure(message: 'Network error'),
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

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('body is scrollable for keyboard safety', (tester) async {
      await tester.pumpWidget(
        _buildPage(
          const ForgotPasswordPage(),
          repository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('ResetPasswordPage', () {
    testWidgets('password visibility toggles work', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(
        _buildPage(
          const ResetPasswordPage(token: 'token'),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(
        find.byKey(const ValueKey('reset-password-input')),
      );
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('reset-password-toggle')));
      await tester.pumpAndSettle();

      final updatedField = tester.widget<TextField>(
        find.byKey(const ValueKey('reset-password-input')),
      );
      expect(updatedField.obscureText, isFalse);
    });

    testWidgets('body is scrollable for keyboard safety', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(
        _buildPage(
          const ResetPasswordPage(token: 'token'),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('VerifyEmailPage', () {
    testWidgets('body is scrollable for keyboard safety', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(
        _buildPage(
          const VerifyEmailPage(),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });
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
  final List<String> loginEmails = [];
  final List<String> registerEmails = [];

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (loginFailure != null) throw loginFailure!;
    loginEmails.add(email);
    return const AuthResult(accessToken: 'token', refreshToken: 'refresh');
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (registerFailure != null) throw registerFailure!;
    registerEmails.add(email);
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

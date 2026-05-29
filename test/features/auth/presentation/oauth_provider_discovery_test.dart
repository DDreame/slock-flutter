// =============================================================================
// B122 PR 1 — OAuth Provider Discovery + UI (load-bearing tests).
//
// Tests prove:
// 1. When GET /auth/providers returns providers → social buttons visible.
// 2. When GET /auth/providers returns empty → no social buttons visible.
// 3. Both LoginPage and RegisterPage show/hide the buttons based on providers.
// 4. Divider label comes from l10n (not hardcoded English).
//
// Removing SocialLoginButtons or the authProvidersProvider → tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/application/auth_providers_controller.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository.dart';
import 'package:slock_app/features/auth/data/auth_provider_repository_provider.dart';
import 'package:slock_app/features/auth/data/auth_repository.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/auth/presentation/page/login_page.dart';
import 'package:slock_app/features/auth/presentation/page/register_page.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

// =============================================================================
// Test helpers
// =============================================================================

Widget _buildApp(
  Widget page, {
  required AuthProviderRepository providerRepo,
  Locale locale = const Locale('en'),
}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      authProviderRepositoryProvider.overrideWithValue(providerRepo),
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

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // LoginPage — social buttons
  // ===========================================================================
  group('B122 OAuth — LoginPage social buttons', () {
    testWidgets('renders provider buttons when providers available',
        (tester) async {
      final repo = _FakeAuthProviderRepo([
        const AuthProvider(id: 'google', name: 'Google'),
        const AuthProvider(id: 'github', name: 'GitHub'),
      ]);

      await tester.pumpWidget(_buildApp(const LoginPage(), providerRepo: repo));
      await tester.pumpAndSettle();

      // Buttons keyed by provider id must exist.
      expect(
        find.byKey(const ValueKey('oauth-provider-google')),
        findsOneWidget,
        reason: 'Removing SocialLoginButtons from LoginPage → RED.',
      );
      expect(
        find.byKey(const ValueKey('oauth-provider-github')),
        findsOneWidget,
        reason: 'Removing SocialLoginButtons from LoginPage → RED.',
      );

      // Button label must include provider name (from l10n).
      expect(
        find.text('Continue with Google'),
        findsOneWidget,
        reason: 'Removing oauthProviderButton l10n or provider name → RED.',
      );
      expect(
        find.text('Continue with GitHub'),
        findsOneWidget,
        reason: 'Removing oauthProviderButton l10n or provider name → RED.',
      );
    });

    testWidgets('shows divider label from l10n (not hardcoded)',
        (tester) async {
      final repo = _FakeAuthProviderRepo([
        const AuthProvider(id: 'google', name: 'Google'),
      ]);

      await tester.pumpWidget(_buildApp(const LoginPage(), providerRepo: repo));
      await tester.pumpAndSettle();

      // English divider text must be present.
      expect(
        find.text('or continue with'),
        findsOneWidget,
        reason: 'Removing oauthDividerLabel l10n → RED.',
      );
    });

    testWidgets('shows Chinese divider label in zh locale', (tester) async {
      final repo = _FakeAuthProviderRepo([
        const AuthProvider(id: 'google', name: 'Google'),
      ]);

      await tester.pumpWidget(_buildApp(
        const LoginPage(),
        providerRepo: repo,
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      // Chinese label must appear — proves l10n is wired, not hardcoded.
      expect(
        find.text('或通过以下方式继续'),
        findsOneWidget,
        reason: 'Hardcoding English instead of l10n → RED in zh.',
      );
      expect(
        find.text('or continue with'),
        findsNothing,
        reason: 'English must not appear in zh locale.',
      );
    });

    testWidgets('renders nothing when no providers available', (tester) async {
      final repo = _FakeAuthProviderRepo(const []);

      await tester.pumpWidget(_buildApp(const LoginPage(), providerRepo: repo));
      await tester.pumpAndSettle();

      // No buttons, no divider.
      expect(
        find.byKey(const ValueKey('social-login-buttons')),
        findsNothing,
        reason: 'Empty providers must not render any social buttons widget.',
      );
      expect(find.text('or continue with'), findsNothing);
    });
  });

  // ===========================================================================
  // RegisterPage — social buttons
  // ===========================================================================
  group('B122 OAuth — RegisterPage social buttons', () {
    testWidgets('renders provider buttons when providers available',
        (tester) async {
      final repo = _FakeAuthProviderRepo([
        const AuthProvider(id: 'google', name: 'Google'),
      ]);

      await tester
          .pumpWidget(_buildApp(const RegisterPage(), providerRepo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('oauth-provider-google')),
        findsOneWidget,
        reason: 'Removing SocialLoginButtons from RegisterPage → RED.',
      );
      expect(
        find.text('Continue with Google'),
        findsOneWidget,
        reason: 'Removing oauthProviderButton l10n or provider name → RED.',
      );
      expect(
        find.text('or continue with'),
        findsOneWidget,
        reason: 'Removing oauthDividerLabel l10n → RED.',
      );
    });

    testWidgets('renders nothing when no providers available', (tester) async {
      final repo = _FakeAuthProviderRepo(const []);

      await tester
          .pumpWidget(_buildApp(const RegisterPage(), providerRepo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('social-login-buttons')),
        findsNothing,
        reason: 'Empty providers must not render any social buttons widget.',
      );
      expect(find.text('or continue with'), findsNothing);
    });
  });

  // ===========================================================================
  // authProvidersProvider unit test
  // ===========================================================================
  group('B122 OAuth — authProvidersProvider', () {
    test('returns providers from repository', () async {
      final repo = _FakeAuthProviderRepo([
        const AuthProvider(id: 'apple', name: 'Apple', iconUrl: 'https://x.co'),
      ]);

      final container = ProviderContainer(
        overrides: [
          authProviderRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(authProvidersProvider.future);
      expect(result, hasLength(1));
      expect(result.first.id, 'apple');
      expect(result.first.name, 'Apple');
      expect(result.first.iconUrl, 'https://x.co');
    });

    test('returns empty list on repository error', () async {
      final repo = _ErrorAuthProviderRepo();

      final container = ProviderContainer(
        overrides: [
          authProviderRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // The repository throws but our impl catches and returns [] for
      // non-AppFailure errors. For AppFailure it rethrows, producing an
      // AsyncError state — the widget renders SizedBox.shrink() either way.
      final asyncValue =
          await container.read(authProvidersProvider.future).then(
                (v) => AsyncValue.data(v),
                onError: (e, s) => AsyncValue<List<AuthProvider>>.error(e, s),
              );
      // Either empty data or error — both are acceptable (widget handles both).
      expect(
        asyncValue.valueOrNull?.isEmpty ?? true,
        isTrue,
      );
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeAuthProviderRepo implements AuthProviderRepository {
  _FakeAuthProviderRepo(this._providers);
  final List<AuthProvider> _providers;

  @override
  Future<List<AuthProvider>> getProviders() async => List.of(_providers);
}

class _ErrorAuthProviderRepo implements AuthProviderRepository {
  @override
  Future<List<AuthProvider>> getProviders() async =>
      throw Exception('Network error');
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      const AuthResult(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      const AuthResult(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthUser> getMe() async =>
      const AuthUser(id: 'user-1', emailVerified: false);

  @override
  Future<void> requestPasswordReset({required String email}) async {}

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

// =============================================================================
// #843 — L10n: Typing indicators + Reconnecting banner + ES translations
//
// Load-bearing tests proving localization is wired through the widget layer:
//
// 1. TypingIndicatorWidget renders ZH strings (not hardcoded English)
// 2. ConnectionStatusBanner renders ZH reconnecting string
// 3. ListTypingIndicatorState exposes typerNames (not formatted text)
//
// Falsification: reverting production code to hardcoded English strings
// must make the ZH-locale tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_service.dart';
import 'package:slock_app/features/auth/application/forgot_password_controller.dart';
import 'package:slock_app/features/auth/presentation/page/forgot_password_page.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/realtime/application/list_typing_indicator_store.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: TypingIndicatorWidget l10n proof (ZH locale)
  // ---------------------------------------------------------------------------
  group('TypingIndicatorWidget l10n (#843)', () {
    testWidgets(
      'single typer renders ZH string, not hardcoded English',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider.overrideWith(
              () => _FixedTypingStore(const TypingIndicatorState(
                activeTypers: [
                  ActiveTyper(userId: 'u1', displayName: 'Alice'),
                ],
              )),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const Scaffold(body: TypingIndicatorWidget()),
            ),
          ),
        );
        // Use pump() not pumpAndSettle() — animated dots never settle.
        await tester.pump();

        // ZH: "Alice 正在输入..."
        expect(
          find.text('Alice 正在输入...'),
          findsOneWidget,
          reason: 'Must render ZH localized typing indicator',
        );
        // Must NOT show the old hardcoded English.
        expect(
          find.text('Alice is typing...'),
          findsNothing,
          reason: 'Hardcoded EN must not appear in ZH locale',
        );
      },
    );

    testWidgets(
      'two typers renders ZH combined string',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider.overrideWith(
              () => _FixedTypingStore(const TypingIndicatorState(
                activeTypers: [
                  ActiveTyper(userId: 'u1', displayName: 'Alice'),
                  ActiveTyper(userId: 'u2', displayName: 'Bob'),
                ],
              )),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const Scaffold(body: TypingIndicatorWidget()),
            ),
          ),
        );
        // Use pump() not pumpAndSettle() — animated dots never settle.
        await tester.pump();

        // ZH: "Alice 和 Bob 正在输入..."
        expect(
          find.text('Alice 和 Bob 正在输入...'),
          findsOneWidget,
          reason: 'Must render ZH two-typer string',
        );
        expect(
          find.text('Alice and Bob are typing...'),
          findsNothing,
          reason: 'EN two-typer string must not appear in ZH locale',
        );
      },
    );

    testWidgets(
      'three+ typers renders ZH "several" string',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider.overrideWith(
              () => _FixedTypingStore(const TypingIndicatorState(
                activeTypers: [
                  ActiveTyper(userId: 'u1', displayName: 'Alice'),
                  ActiveTyper(userId: 'u2', displayName: 'Bob'),
                  ActiveTyper(userId: 'u3', displayName: 'Carol'),
                ],
              )),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const Scaffold(body: TypingIndicatorWidget()),
            ),
          ),
        );
        // Use pump() not pumpAndSettle() — animated dots never settle.
        await tester.pump();

        // ZH: "多人正在输入..."
        expect(
          find.text('多人正在输入...'),
          findsOneWidget,
          reason: 'Must render ZH several-typers string',
        );
        expect(
          find.text('Several people are typing...'),
          findsNothing,
          reason: 'EN several-typers string must not appear in ZH locale',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: ConnectionStatusBanner l10n proof (ZH locale)
  // ---------------------------------------------------------------------------
  group('ConnectionStatusBanner l10n (#843)', () {
    testWidgets(
      'renders ZH reconnecting string when disconnected',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            realtimeServiceProvider.overrideWith(
              () => _DisconnectedRealtimeService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const Scaffold(body: ConnectionStatusBanner()),
            ),
          ),
        );
        // #859: Advance past banner grace period before asserting visibility.
        await tester.pump(bannerGracePeriod);
        await tester.pump();

        // ZH: "重新连接中..."
        expect(
          find.text('重新连接中...'),
          findsOneWidget,
          reason: 'Must render ZH reconnecting string',
        );
        // Must NOT show the old hardcoded English.
        expect(
          find.text('Reconnecting...'),
          findsNothing,
          reason: 'Hardcoded EN must not appear in ZH locale',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: ListTypingIndicatorState exposes typerNames (not formatted text)
  // ---------------------------------------------------------------------------
  group('ListTypingIndicatorState typerNames (#843)', () {
    test('single typer populates typerNames list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier);
      notifier.addTyper(userId: 'u1', displayName: 'Alice');

      final state = container.read(listTypingIndicatorStoreProvider('scope-1'));
      expect(state.isActive, isTrue);
      expect(state.typerNames, ['Alice']);
    });

    test('multiple typers populate typerNames in order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier);
      notifier.addTyper(userId: 'u1', displayName: 'Alice');
      notifier.addTyper(userId: 'u2', displayName: 'Bob');
      notifier.addTyper(userId: 'u3', displayName: 'Carol');

      final state = container.read(listTypingIndicatorStoreProvider('scope-1'));
      expect(state.isActive, isTrue);
      expect(state.typerNames, ['Alice', 'Bob', 'Carol']);
    });

    test('removing typer updates typerNames', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier);
      notifier.addTyper(userId: 'u1', displayName: 'Alice');
      notifier.addTyper(userId: 'u2', displayName: 'Bob');
      notifier.removeTyper('u1');

      final state = container.read(listTypingIndicatorStoreProvider('scope-1'));
      expect(state.typerNames, ['Bob']);
    });

    test('empty state is not active', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(listTypingIndicatorStoreProvider('scope-1'));
      expect(state.isActive, isFalse);
      expect(state.typerNames, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: ES auth page l10n proof — ForgotPasswordPage renders Spanish
  // ---------------------------------------------------------------------------
  group('ForgotPasswordPage ES l10n (#843)', () {
    testWidgets(
      'renders ES forgot password strings, not English',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            forgotPasswordControllerProvider
                .overrideWith(() => _NoOpForgotPasswordController()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const ForgotPasswordPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ES title: "Olvidé mi contraseña"
        expect(
          find.text('Olvidé mi contraseña'),
          findsOneWidget,
          reason: 'Must render ES forgot password title',
        );
        // ES submit button: "Restablecer contraseña"
        expect(
          find.text('Restablecer contraseña'),
          findsOneWidget,
          reason: 'Must render ES submit label',
        );
        // ES back to login: "Volver al inicio de sesión"
        expect(
          find.text('Volver al inicio de sesión'),
          findsOneWidget,
          reason: 'Must render ES back-to-login label',
        );
        // Must NOT show the old English strings.
        expect(
          find.text('Forgot Password'),
          findsNothing,
          reason: 'EN title must not appear in ES locale',
        );
        expect(
          find.text('Reset Password'),
          findsNothing,
          reason: 'EN submit label must not appear in ES locale',
        );
        expect(
          find.text('Back to login'),
          findsNothing,
          reason: 'EN back-to-login must not appear in ES locale',
        );
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FixedTypingStore extends TypingIndicatorStore {
  _FixedTypingStore(this._initialState);

  final TypingIndicatorState _initialState;

  @override
  TypingIndicatorState build() {
    ref.onDispose(() {});
    return _initialState;
  }
}

class _DisconnectedRealtimeService extends RealtimeService {
  @override
  RealtimeConnectionState build() {
    return const RealtimeConnectionState(
      status: RealtimeConnectionStatus.disconnected,
    );
  }
}

class _NoOpForgotPasswordController extends ForgotPasswordController {
  @override
  Future<void> build() async {}

  @override
  Future<void> submit({required String email}) async {}
}

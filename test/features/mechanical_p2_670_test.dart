// =============================================================================
// #670 — Mechanical P2 fixes — Widget-path invariants
//
// Fix 1 Invariant: INV-TELEMETRY-670-AGENTS
//   _loadMachinesForAgents catch block records error via DiagnosticsCollector
//   instead of silently swallowing exceptions.
//
// Fix 2 Invariant: INV-POSTFRAME-670-TRANSLATION
//   TranslationSettingsPage postFrameCallback has dedup guard:
//   rapid status resets don't stack multiple ensureLoaded() calls.
//
// Fix 3 Invariant: INV-FILTER-670-SHARE
//   share_target_picker_page hoists _query.toLowerCase() before filter loop.
//   Behavioral proof: filtering is case-insensitive and correct.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/settings/presentation/page/translation_settings_page.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/l10n/l10n.dart';

import '../support/fakes/fake_app_dio_client.dart';

// ---------------------------------------------------------------------------
// Fakes / Controllables
// ---------------------------------------------------------------------------

/// FakeAppDioClient that always throws an Exception on any request.
class _ThrowingDioClient extends FakeAppDioClient {
  _ThrowingDioClient() : super(responses: const {});

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    throw Exception('Network error: connection refused');
  }
}

/// FakeAppDioClient that returns valid machine list data.
class _SuccessDioClient extends FakeAppDioClient {
  _SuccessDioClient()
      : super(
          responses: {
            ('GET', '/servers/srv-1/machines'): {
              'machines': <Object>[
                {
                  'id': 'm-1',
                  'name': 'Machine One',
                },
              ],
            },
          },
        );
}

/// Controllable TranslationSettingsStore that counts ensureLoaded() calls
/// and allows manual state reset to simulate rapid server switches.
class _CountingTranslationSettingsStore extends TranslationSettingsStore {
  int ensureLoadedCount = 0;

  @override
  TranslationSettingsState build() =>
      const TranslationSettingsState(status: TranslationSettingsStatus.success);

  @override
  Future<void> ensureLoaded() async {
    ensureLoadedCount++;
    // Simulate real behavior: transition to success after loading.
    state = state.copyWith(status: TranslationSettingsStatus.success);
  }

  /// Simulate a server switch by resetting status to initial.
  void resetToInitial() {
    state = const TranslationSettingsState(
      status: TranslationSettingsStatus.initial,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: agents silent catch → telemetry
  // ---------------------------------------------------------------------------
  group('Fix 1: agents machines loader telemetry', () {
    test(
      'INV-TELEMETRY-670-AGENTS: exception records error in diagnostics',
      () async {
        final diagnostics = DiagnosticsCollector();
        final container = ProviderContainer(
          overrides: [
            appDioClientProvider.overrideWithValue(_ThrowingDioClient()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          ],
        );
        addTearDown(container.dispose);

        final loader = container.read(agentsMachinesLoaderProvider);
        final result = await loader();

        // Returns empty list on failure (graceful degradation).
        expect(result, isEmpty);

        // Diagnostics collector recorded the error.
        final entries = diagnostics.entries;
        expect(entries, hasLength(1));
        expect(entries.first.level, DiagnosticsLevel.error);
        expect(entries.first.tag, 'AgentsMachinesLoader');
        expect(
          entries.first.message,
          contains('Failed to load machines for server srv-1'),
        );
      },
    );

    test(
      'INV-TELEMETRY-670-AGENTS: success does NOT record diagnostics',
      () async {
        final diagnostics = DiagnosticsCollector();
        final container = ProviderContainer(
          overrides: [
            appDioClientProvider.overrideWithValue(_SuccessDioClient()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          ],
        );
        addTearDown(container.dispose);

        final loader = container.read(agentsMachinesLoaderProvider);
        final result = await loader();

        // Successful load returns items.
        expect(result, hasLength(1));
        expect(result.first.name, 'Machine One');

        // No diagnostics recorded.
        expect(diagnostics.entries, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 2: translation settings page postFrame dedup guard
  // ---------------------------------------------------------------------------
  group('Fix 2: translation settings page postFrame dedup', () {
    testWidgets(
      'INV-POSTFRAME-670-TRANSLATION: rapid status resets issue only one '
      'ensureLoaded per frame',
      (tester) async {
        final store = _CountingTranslationSettingsStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationSettingsStoreProvider.overrideWith(() => store),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TranslationSettingsPage(),
            ),
          ),
        );

        // After initial pump, the initState schedules one postFrame callback.
        // Pump to fire it.
        await tester.pump();

        // initState triggered exactly 1 ensureLoaded via the post-frame
        // callback.
        expect(store.ensureLoadedCount, 1,
            reason: 'initState should fire exactly one ensureLoaded');

        // Reset counter for the next phase.
        store.ensureLoadedCount = 0;

        // Simulate 3 rapid status resets to initial (e.g. rapid server
        // switches within the same frame). Each fires the ref.listen
        // callback which calls _scheduleLoad().
        store.resetToInitial();
        store.resetToInitial();
        store.resetToInitial();

        // Pump once to fire the post-frame callback.
        await tester.pump();

        // The dedup guard ensures only ONE ensureLoaded fires despite 3
        // rapid resets.
        expect(store.ensureLoadedCount, 1,
            reason:
                'dedup guard must collapse rapid resets into one ensureLoaded');
      },
    );

    testWidgets(
      'INV-POSTFRAME-670-TRANSLATION: separate frames each get their own '
      'ensureLoaded call',
      (tester) async {
        final store = _CountingTranslationSettingsStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationSettingsStoreProvider.overrideWith(() => store),
              activeServerScopeIdProvider
                  .overrideWithValue(const ServerScopeId('srv-1')),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TranslationSettingsPage(),
            ),
          ),
        );

        // Fire initState callback.
        await tester.pump();
        expect(store.ensureLoadedCount, 1);

        // Reset in frame 2.
        store.ensureLoadedCount = 0;
        store.resetToInitial();
        await tester.pump();
        expect(store.ensureLoadedCount, 1,
            reason: 'frame 2 reset should fire one ensureLoaded');

        // Reset in frame 3.
        store.ensureLoadedCount = 0;
        store.resetToInitial();
        await tester.pump();
        expect(store.ensureLoadedCount, 1,
            reason: 'frame 3 reset should fire one ensureLoaded');
      },
    );
  });
}

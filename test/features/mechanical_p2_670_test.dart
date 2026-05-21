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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';

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
}

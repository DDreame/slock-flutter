import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

void main() {
  AgentItem makeAgent({
    String id = 'agent-1',
    String name = 'Bot',
    String? description,
    String model = 'sonnet',
    String runtime = 'claude',
    String? reasoningEffort,
    String? machineId,
    String status = 'active',
    String activity = 'online',
  }) {
    return AgentItem(
      id: id,
      name: name,
      description: description,
      model: model,
      runtime: runtime,
      reasoningEffort: reasoningEffort,
      machineId: machineId,
      status: status,
      activity: activity,
    );
  }

  group('AgentsPage direct detail route', () {
    testWidgets('shows failure + retry on load failure', (tester) async {
      final fakeRepo = _FailingAgentsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(home: AgentsPage(agentId: 'agent-1')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load agents.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.text('Agent not found.'), findsNothing);
    });

    testWidgets('retry reloads after failure', (tester) async {
      final fakeRepo = _QueueAgentsRepository(
        results: [
          const _RepoResult.failure('Failed to load agents.'),
          const _RepoResult.success([
            AgentItem(
              id: 'agent-1',
              name: 'Bot',
              model: 'sonnet',
              runtime: 'claude',
              status: 'active',
              activity: 'online',
            ),
          ]),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(home: AgentsPage(agentId: 'agent-1')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load agents.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Bot'), findsOneWidget);
      expect(find.text('Failed to load agents.'), findsNothing);
    });

    testWidgets(
      'list tap pushes server-scoped detail route and preserves list back stack',
      (tester) async {
        final fakeRepo = _QueueAgentsRepository(
          results: [
            const _RepoResult.success([
              AgentItem(
                id: 'agent-1',
                name: 'Bot',
                model: 'sonnet',
                runtime: 'claude',
                status: 'active',
                activity: 'online',
              ),
            ]),
          ],
        );
        final router = GoRouter(
          initialLocation: '/servers/server-1/agents',
          routes: [
            GoRoute(
              path: '/servers/:serverId/agents',
              builder: (context, state) =>
                  AgentsPage(serverId: state.pathParameters['serverId']),
            ),
            GoRoute(
              path: '/servers/:serverId/agents/:agentId',
              builder: (context, state) => Scaffold(
                body: Text(
                  'agent:${state.pathParameters['serverId']}/${state.pathParameters['agentId']}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeRepo),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('agent-agent-1')));
        await tester.pumpAndSettle();

        expect(find.text('agent:server-1/agent-1'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agents-list')), findsOneWidget);
        expect(find.text('Bot'), findsOneWidget);
      },
    );

    testWidgets(
      'message button pushes DM route and preserves agent detail back stack',
      (tester) async {
        final fakeRepo = _MutableAgentsRepository(
          initialItems: [
            makeAgent(
              id: 'agent-1',
              name: 'Bot',
              model: 'sonnet',
              runtime: 'claude',
            ),
          ],
        );
        final fakeMemberRepo = _FakeMemberRepository(
          agentDmChannelId: 'dm-agent-999',
        );
        final router = GoRouter(
          initialLocation: '/servers/server-1/agents/agent-1',
          routes: [
            GoRoute(
              path: '/servers/:serverId/agents',
              builder: (context, state) =>
                  AgentsPage(serverId: state.pathParameters['serverId']),
            ),
            GoRoute(
              path: '/servers/:serverId/agents/:agentId',
              builder: (context, state) => AgentsPage(
                serverId: state.pathParameters['serverId'],
                agentId: state.pathParameters['agentId'],
              ),
            ),
            GoRoute(
              path: '/servers/:serverId/dms/:channelId',
              builder: (context, state) => Scaffold(
                body: Text(
                  'dm:${state.pathParameters['serverId']}/${state.pathParameters['channelId']}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeRepo),
              memberRepositoryProvider.overrideWithValue(fakeMemberRepo),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('agent-message-btn')));
        await tester.pumpAndSettle();

        // Verify navigation reached the DM route.
        expect(
          find.text('dm:server-1/dm-agent-999'),
          findsOneWidget,
        );
        expect(fakeMemberRepo.openedAgentDmIds, ['agent-1']);

        // Pop back — agent detail should still be on the stack
        // (context.push, not context.go).
        router.pop();
        await tester.pumpAndSettle();

        expect(find.text('Bot'), findsOneWidget);
      },
    );

    testWidgets(
      'detail route loads REST activity log on mount and renders realtime events',
      (tester) async {
        final fakeRepo = _MutableAgentsRepository(
          initialItems: [
            makeAgent(
              id: 'agent-1',
              name: 'Bot',
              model: 'sonnet',
              runtime: 'claude',
            ),
          ],
        );
        final ingress = RealtimeReductionIngress();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeRepo),
              realtimeReductionIngressProvider.overrideWithValue(ingress),
            ],
            child: const MaterialApp(home: AgentsPage(agentId: 'agent-1')),
          ),
        );

        await tester.pumpAndSettle();

        // REST load triggered exactly once on mount.
        expect(fakeRepo.getActivityLogCallCount, 1);
        // No entries returned by default, so still shows empty.
        expect(find.text('No activity log entries.'), findsOneWidget);

        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'agent:activity',
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 30, 16, 55, 42),
            payload: const {
              'agentId': 'agent-1',
              'activity': 'working',
              'detail': 'Running flutter test',
            },
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('16:55:42'), findsOneWidget);
        expect(find.text('Working: Running flutter test'), findsOneWidget);
        expect(find.text('No activity log entries.'), findsNothing);
        // No additional REST call from the realtime event.
        expect(fakeRepo.getActivityLogCallCount, 1);
      },
    );

    testWidgets(
      'mount-trigger fetches REST history and renders entries in UI',
      (tester) async {
        final fakeRepo = _MutableAgentsRepository(
          initialItems: [
            makeAgent(
              id: 'agent-1',
              name: 'Bot',
              model: 'sonnet',
              runtime: 'claude',
            ),
          ],
        );
        fakeRepo.activityLogResult = [
          AgentActivityLogEntry(
            timestamp: DateTime(2026, 5, 1, 9, 30, 15),
            entry: 'Working: deploying service',
          ),
          AgentActivityLogEntry(
            timestamp: DateTime(2026, 5, 1, 9, 31, 0),
            entry: 'Online',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeRepo),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: const MaterialApp(home: AgentsPage(agentId: 'agent-1')),
          ),
        );

        await tester.pumpAndSettle();

        // getActivityLog called exactly once on mount.
        expect(fakeRepo.getActivityLogCallCount, 1);
        // Historical entries rendered.
        expect(find.text('09:30:15'), findsOneWidget);
        expect(find.text('Working: deploying service'), findsOneWidget);
        expect(find.text('09:31:00'), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
        // Empty placeholder gone.
        expect(find.text('No activity log entries.'), findsNothing);
      },
    );

    testWidgets(
      'create flow submits machine/runtime/model config from dialog',
      (tester) async {
        final fakeRepo = _MutableAgentsRepository(initialItems: const []);
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('GET', '/servers/server-1/machines'): {
              'machines': [
                {
                  'id': 'machine-1',
                  'name': 'Build node',
                  'status': 'online',
                  'runtimes': ['codex', 'claude'],
                },
              ],
            },
            (
              'GET',
              '/servers/server-1/machines/machine-1/runtime-models/codex',
            ): {
              'default': 'gpt-5.4',
              'models': [
                {'id': 'gpt-5.4', 'label': 'GPT-5.4'},
                {'id': 'gpt-5.2', 'label': 'GPT-5.2'},
              ],
            },
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentsRepositoryProvider.overrideWithValue(fakeRepo),
              appDioClientProvider.overrideWithValue(appDioClient),
              realtimeReductionIngressProvider.overrideWithValue(
                RealtimeReductionIngress(),
              ),
            ],
            child: const MaterialApp(home: AgentsPage(serverId: 'server-1')),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No agents yet.'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('agents-create-fab')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('agent-form-name')),
          'Builder',
        );
        await tester.tap(find.byKey(const ValueKey('agent-form-submit')));
        await tester.pumpAndSettle();

        expect(fakeRepo.createRequests, hasLength(1));
        expect(fakeRepo.createRequests.single.name, 'Builder');
        expect(fakeRepo.createRequests.single.machineId, 'machine-1');
        expect(fakeRepo.createRequests.single.runtime, 'codex');
        expect(fakeRepo.createRequests.single.model, 'gpt-5.4');
        expect(fakeRepo.createRequests.single.reasoningEffort, 'medium');
        expect(find.text('Builder'), findsOneWidget);
      },
    );

    testWidgets('detail edit flow updates the agent through the store', (
      tester,
    ) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(
            id: 'agent-1',
            name: 'Bot',
            description: 'Original',
            model: 'sonnet',
            runtime: 'claude',
            machineId: 'machine-1',
          ),
        ],
      );
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/server-1/machines'): {
            'machines': [
              {
                'id': 'machine-1',
                'name': 'Build node',
                'status': 'online',
                'runtimes': ['claude'],
              },
            ],
          },
          (
            'GET',
            '/servers/server-1/machines/machine-1/runtime-models/claude',
          ): {
            'default': 'sonnet',
            'models': [
              {'id': 'sonnet', 'label': 'Sonnet'},
              {'id': 'opus', 'label': 'Opus'},
            ],
          },
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            appDioClientProvider.overrideWithValue(appDioClient),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-edit-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('agent-form-name')),
        'Bot Prime',
      );
      await tester.tap(find.byKey(const ValueKey('agent-form-submit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.updateRequests, hasLength(1));
      expect(fakeRepo.updateRequests.single.$1, 'agent-1');
      expect(fakeRepo.updateRequests.single.$2.name, 'Bot Prime');
      expect(fakeRepo.updateRequests.single.$2.machineId, 'machine-1');
      expect(find.text('Bot Prime'), findsWidgets);
    });

    testWidgets('detail delete flow removes the agent', (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(
            id: 'agent-1',
            name: 'Bot',
            model: 'sonnet',
            runtime: 'claude',
            machineId: 'machine-1',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-delete-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-delete-confirm')));
      await tester.pumpAndSettle();

      expect(fakeRepo.deletedAgentIds, ['agent-1']);
      expect(find.text('Agent not found.'), findsOneWidget);
    });
  });

  group('Agent control action guards', () {
    testWidgets('activity dots use theme-safe colors in dark theme', (
      tester,
    ) async {
      final theme = AppTheme.dark;
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-online', activity: 'online'),
          makeAgent(id: 'agent-thinking', activity: 'thinking'),
          makeAgent(id: 'agent-working', activity: 'working'),
          makeAgent(id: 'agent-error', activity: 'error'),
          makeAgent(
            id: 'agent-offline',
            status: 'stopped',
            activity: 'offline',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: const AgentsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color dotColor(String agentId) {
        final widget = tester.widget<Container>(
          find.byKey(ValueKey('agent-activity-$agentId')),
        );
        final decoration = widget.decoration! as BoxDecoration;
        return decoration.color!;
      }

      expect(dotColor('agent-online'), theme.colorScheme.secondary);
      expect(dotColor('agent-thinking'), theme.colorScheme.tertiary);
      expect(dotColor('agent-working'), theme.colorScheme.primary);
      expect(dotColor('agent-error'), theme.colorScheme.error);
      expect(dotColor('agent-offline'), theme.colorScheme.outline);
    });

    testWidgets('stop button shows confirmation and calls stopAgent on confirm',
        (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-1', name: 'Bot', status: 'active'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-stop-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Stop Agent?'), findsOneWidget);
      expect(fakeRepo.stoppedAgentIds, isEmpty);

      await tester.tap(find.byKey(const ValueKey('agent-stop-confirm')));
      await tester.pumpAndSettle();

      expect(fakeRepo.stoppedAgentIds, ['agent-1']);
    });

    testWidgets('stop confirmation cancel does not call stopAgent',
        (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-1', name: 'Bot', status: 'active'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-stop-btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeRepo.stoppedAgentIds, isEmpty);
    });

    testWidgets(
        'reset button shows confirmation and calls resetAgent on confirm',
        (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-1', name: 'Bot', status: 'active'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-reset-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Session?'), findsOneWidget);
      expect(fakeRepo.resetAgentIds, isEmpty);

      await tester.tap(find.byKey(const ValueKey('agent-reset-confirm')));
      await tester.pumpAndSettle();

      expect(fakeRepo.resetAgentIds, ['agent-1']);
    });

    testWidgets('reset confirmation cancel does not call resetAgent',
        (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-1', name: 'Bot', status: 'active'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-reset-btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeRepo.resetAgentIds, isEmpty);
    });

    testWidgets('start has no confirmation dialog', (tester) async {
      final fakeRepo = _MutableAgentsRepository(
        initialItems: [
          makeAgent(id: 'agent-1', name: 'Bot', status: 'stopped'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(fakeRepo),
            realtimeReductionIngressProvider.overrideWithValue(
              RealtimeReductionIngress(),
            ),
          ],
          child: const MaterialApp(
            home: AgentsPage(agentId: 'agent-1', serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('agent-start-btn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.startedAgentIds, ['agent-1']);
      expect(find.text('Stop Agent?'), findsNothing);
      expect(find.text('Reset Session?'), findsNothing);
    });
  });
}

class _FailingAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<List<AgentItem>> listAgents() async {
    throw const UnknownFailure(
      message: 'Failed to load agents.',
      causeType: 'test',
    );
  }

  @override
  Future<void> startAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> stopAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];
}

sealed class _RepoResult {
  const _RepoResult();
  const factory _RepoResult.success(List<AgentItem> items) = _SuccessResult;
  const factory _RepoResult.failure(String message) = _FailureResult;
}

class _SuccessResult extends _RepoResult {
  const _SuccessResult(this.items);
  final List<AgentItem> items;
}

class _FailureResult extends _RepoResult {
  const _FailureResult(this.message);
  final String message;
}

class _QueueAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  _QueueAgentsRepository({required List<_RepoResult> results})
      : _results = List.of(results);

  final List<_RepoResult> _results;
  int _index = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    final result = _results[_index++];
    return switch (result) {
      _SuccessResult(:final items) => items,
      _FailureResult(:final message) => throw UnknownFailure(
          message: message,
          causeType: 'test',
        ),
    };
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> startAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> stopAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];
}

class _MutableAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  _MutableAgentsRepository({required List<AgentItem> initialItems})
      : _items = List.of(initialItems);

  final List<AgentItem> _items;
  int getActivityLogCallCount = 0;
  final List<AgentMutationInput> createRequests = [];
  final List<(String, AgentMutationInput)> updateRequests = [];
  final List<String> deletedAgentIds = [];

  @override
  Future<List<AgentItem>> listAgents() async => List.of(_items);

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    createRequests.add(input);
    final created = AgentItem(
      id: 'agent-${_items.length + 1}',
      name: input.name,
      description: input.description,
      model: input.model,
      runtime: input.runtime,
      reasoningEffort: input.reasoningEffort,
      machineId: input.machineId,
      status: 'stopped',
      activity: 'offline',
    );
    _items.add(created);
    return created;
  }

  @override
  Future<AgentItem> updateAgent(
    String agentId,
    AgentMutationInput input,
  ) async {
    updateRequests.add((agentId, input));
    final updated = AgentItem(
      id: agentId,
      name: input.name,
      description: input.description,
      model: input.model,
      runtime: input.runtime,
      reasoningEffort: input.reasoningEffort,
      machineId: input.machineId,
      status: 'active',
      activity: 'online',
    );
    final index = _items.indexWhere((agent) => agent.id == agentId);
    if (index >= 0) {
      _items[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteAgent(String agentId) async {
    deletedAgentIds.add(agentId);
    _items.removeWhere((agent) => agent.id == agentId);
  }

  @override
  Future<void> startAgent(String agentId) async {
    startedAgentIds.add(agentId);
  }

  @override
  Future<void> stopAgent(String agentId) async {
    stoppedAgentIds.add(agentId);
  }

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    resetAgentIds.add(agentId);
  }

  final List<String> startedAgentIds = [];
  final List<String> stoppedAgentIds = [];
  final List<String> resetAgentIds = [];
  List<AgentActivityLogEntry> activityLogResult = const [];

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async {
    getActivityLogCallCount += 1;
    return activityLogResult;
  }
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<(String, String), Object?> responses = const {}})
      : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path, method: method),
      data: _responses[key] as T,
    );
  }
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({this.agentDmChannelId = 'dm-agent-channel-1'});

  final String agentDmChannelId;
  final List<String> openedAgentDmIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async =>
      const [];

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-code';

  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}

  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-channel-1';

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async {
    openedAgentDmIds.add(agentId);
    return agentDmChannelId;
  }
}

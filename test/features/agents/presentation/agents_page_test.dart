import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';

void main() {
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

    testWidgets('list tap pushes detail route and preserves list back stack', (
      tester,
    ) async {
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
        initialLocation: '/agents',
        routes: [
          GoRoute(
            path: '/agents',
            builder: (context, state) => const AgentsPage(),
          ),
          GoRoute(
            path: '/agents/:agentId',
            builder: (context, state) => Scaffold(
              body: Text('agent:${state.pathParameters['agentId']}'),
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

      expect(find.text('agent:agent-1'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agents-list')), findsOneWidget);
      expect(find.text('Bot'), findsOneWidget);
    });
  });
}

class _FailingAgentsRepository implements AgentsRepository {
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
  }) async => [];
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

class _QueueAgentsRepository implements AgentsRepository {
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
  }) async => [];
}

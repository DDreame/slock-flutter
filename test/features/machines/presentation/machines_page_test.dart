import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/machines/presentation/page/machines_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  testWidgets('MachinesPage renders loaded machine list and daemon summary', (
    tester,
  ) async {
    final repository = _FakeMachinesRepository(
      snapshot: const MachinesSnapshot(
        items: [
          MachineItem(
            id: 'machine-1',
            name: 'Builder',
            status: 'online',
            runtimes: ['codex'],
            hostname: 'builder.local',
            daemonVersion: '1.2.3',
          ),
        ],
        latestDaemonVersion: '1.2.3',
      ),
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machines-list')),
    );
    expect(find.text('1 machine(s)'), findsOneWidget);
    expect(find.text('Builder'), findsOneWidget);
    expect(find.text('Latest daemon'), findsOneWidget);
    expect(
      find.textContaining('builder.local', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('empty state can register machine and reveal api key', (
    tester,
  ) async {
    final repository = _FakeMachinesRepository(
      snapshot: const MachinesSnapshot(),
      registerResult: const RegisterMachineResult(
        machine: MachineItem(id: 'machine-2', name: 'Runner', status: 'online'),
        apiKey: 'sk-machine-2-secret',
      ),
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machines-empty')),
    );

    await tester.tap(find.byKey(const ValueKey('machines-create-empty')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('machines-name-field')),
      'Runner',
    );
    await tester.tap(find.byKey(const ValueKey('machines-name-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Machine Registered'), findsOneWidget);
    expect(find.byKey(const ValueKey('machine-api-key-value')), findsOneWidget);
    expect(find.text('Runner'), findsWidgets);
    expect(repository.registeredNames, ['Runner']);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Runner'), findsOneWidget);
  });

  testWidgets('machine actions rename rotate and delete', (tester) async {
    final repository = _FakeMachinesRepository(
      snapshot: const MachinesSnapshot(
        items: [
          MachineItem(id: 'machine-1', name: 'Builder', status: 'offline'),
        ],
      ),
      rotatedKey: 'sk-rotated-value',
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machine-actions-machine-1')),
    );

    await tester.tap(find.byKey(const ValueKey('machine-actions-machine-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('machines-name-field')),
      'Builder Prime',
    );
    await tester.tap(find.byKey(const ValueKey('machines-name-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Builder Prime'), findsOneWidget);
    expect(repository.renameRequests, [('machine-1', 'Builder Prime')]);

    await tester.tap(find.byKey(const ValueKey('machine-actions-machine-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate API Key').last);
    await tester.pumpAndSettle();

    expect(find.text('Rotated API Key'), findsOneWidget);
    expect(find.text('sk-rotated-value'), findsOneWidget);
    expect(repository.rotatedMachineIds, ['machine-1']);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('machine-actions-machine-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('machines-confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('machine-machine-1')), findsNothing);
    expect(repository.deletedMachineIds, ['machine-1']);
  });

  testWidgets('failure state retries load', (tester) async {
    final repository = _FakeMachinesRepository(
      failureQueue: [
        const UnknownFailure(message: 'Load failed', causeType: 'test'),
        null,
      ],
      snapshot: const MachinesSnapshot(
        items: [MachineItem(id: 'machine-1', name: 'Builder')],
      ),
    );

    await tester.pumpWidget(_buildApp(repository));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machines-error')),
    );
    expect(find.text('Load failed'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machines-list')),
    );
    expect(find.text('Builder'), findsOneWidget);
  });

  testWidgets('status chips use theme-safe tokens in dark theme', (
    tester,
  ) async {
    final theme = AppTheme.dark;
    final repository = _FakeMachinesRepository(
      snapshot: const MachinesSnapshot(
        items: [
          MachineItem(id: 'machine-online', name: 'Builder', status: 'online'),
          MachineItem(
            id: 'machine-offline',
            name: 'Runner',
            status: 'offline',
          ),
          MachineItem(id: 'machine-error', name: 'Edge', status: 'error'),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(repository, theme: theme));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('machines-list')),
    );

    Chip chipForLabel(String label) {
      return tester.widget<Chip>(
        find.ancestor(of: find.text(label), matching: find.byType(Chip)),
      );
    }

    final onlineChip = chipForLabel('Online');
    expect(onlineChip.backgroundColor, theme.colorScheme.secondaryContainer);
    expect(
        onlineChip.labelStyle?.color, theme.colorScheme.onSecondaryContainer);

    final offlineChip = chipForLabel('Offline');
    expect(
        offlineChip.backgroundColor, theme.colorScheme.surfaceContainerHighest);
    expect(offlineChip.labelStyle?.color, theme.colorScheme.onSurfaceVariant);

    final errorChip = chipForLabel('Error');
    expect(errorChip.backgroundColor, theme.colorScheme.errorContainer);
    expect(errorChip.labelStyle?.color, theme.colorScheme.onErrorContainer);
  });

  testWidgets(
    '#750 carry: popup → Workspaces → list renders → delete → confirm → API',
    (tester) async {
      final repository = _FakeMachinesRepository(
        snapshot: const MachinesSnapshot(
          items: [
            MachineItem(id: 'machine-1', name: 'Builder', status: 'online'),
          ],
        ),
        workspaces: [
          WorkspaceItem(
            id: 'ws-1',
            name: 'Agent Alpha',
            machineId: 'machine-1',
            createdAt: DateTime(2026, 1, 15),
            path: '/home/user/.slock/agents/alpha',
            agentId: 'agent-1',
            agentName: 'Alpha',
            status: 'active',
          ),
          WorkspaceItem(
            id: 'ws-2',
            name: 'Agent Beta',
            machineId: 'machine-1',
            createdAt: DateTime(2026, 1, 16),
            status: 'active',
          ),
        ],
      );

      await tester.pumpWidget(_buildApp(repository));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('machine-actions-machine-1')),
      );

      // Tap popup menu.
      await tester.tap(find.byKey(const ValueKey('machine-actions-machine-1')));
      await tester.pumpAndSettle();

      // Tap "Workspaces" action.
      await tester.tap(find.text('Workspaces').last);
      await tester.pumpAndSettle();

      // Wait for workspace list to load.
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('workspaces-list')),
      );

      // Verify workspace items rendered.
      expect(find.text('Agent Alpha'), findsOneWidget);
      expect(find.text('Agent Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets); // agent chip

      // Tap delete button for ws-1.
      await tester.tap(find.byKey(const ValueKey('workspace-delete-ws-1')));
      await tester.pumpAndSettle();

      // Confirm dialog appeared.
      expect(find.byKey(const ValueKey('workspaces-confirm-delete')),
          findsOneWidget);

      // Tap confirm.
      await tester.tap(find.byKey(const ValueKey('workspaces-confirm-delete')));
      await tester.pumpAndSettle();

      // Verify API was called.
      expect(repository.deletedWorkspaces, [('machine-1', 'ws-1')]);

      // Workspace should be removed from the list.
      expect(find.text('Agent Alpha'), findsNothing);
      expect(find.text('Agent Beta'), findsOneWidget);
    },
  );
}

Widget _buildApp(_FakeMachinesRepository repository, {ThemeData? theme}) {
  final ingress = RealtimeReductionIngress();
  return ProviderScope(
    overrides: [
      machinesRepositoryProvider.overrideWithValue(repository),
      realtimeReductionIngressProvider.overrideWithValue(ingress),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: MachinesPage(serverId: 'server-1'),
    ),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  expect(finder, findsOneWidget);
}

class _FakeMachinesRepository implements MachinesRepository {
  _FakeMachinesRepository({
    this.snapshot = const MachinesSnapshot(),
    this.registerResult = const RegisterMachineResult(
      machine: MachineItem(id: 'machine-2', name: 'Runner'),
      apiKey: 'sk-machine-2-secret',
    ),
    this.rotatedKey = 'sk-rotated-value',
    this.workspaces = const [],
    List<AppFailure?> failureQueue = const [],
  }) : _failureQueue = List.of(failureQueue);

  MachinesSnapshot snapshot;
  RegisterMachineResult registerResult;
  String rotatedKey;
  List<WorkspaceItem> workspaces;
  final List<AppFailure?> _failureQueue;
  final List<String> registeredNames = [];
  final List<(String, String)> renameRequests = [];
  final List<String> rotatedMachineIds = [];
  final List<String> deletedMachineIds = [];
  final List<(String, String)> deletedWorkspaces = [];

  @override
  Future<MachinesSnapshot> loadMachines() async {
    if (_failureQueue.isNotEmpty) {
      final next = _failureQueue.removeAt(0);
      if (next != null) {
        throw next;
      }
    }
    return snapshot;
  }

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async {
    registeredNames.add(name);
    final machine = registerResult.machine.copyWith(name: name);
    snapshot = MachinesSnapshot(
      items: [...snapshot.items, machine],
      latestDaemonVersion: snapshot.latestDaemonVersion,
    );
    return RegisterMachineResult(
      machine: machine,
      apiKey: registerResult.apiKey,
    );
  }

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {
    renameRequests.add((machineId, name));
    snapshot = MachinesSnapshot(
      items: snapshot.items
          .map(
            (machine) => machine.id == machineId
                ? machine.copyWith(name: name)
                : machine,
          )
          .toList(growable: false),
      latestDaemonVersion: snapshot.latestDaemonVersion,
    );
  }

  @override
  Future<String> rotateMachineApiKey(String machineId) async {
    rotatedMachineIds.add(machineId);
    return rotatedKey;
  }

  @override
  Future<void> deleteMachine(String machineId) async {
    deletedMachineIds.add(machineId);
    snapshot = MachinesSnapshot(
      items: snapshot.items
          .where((machine) => machine.id != machineId)
          .toList(growable: false),
      latestDaemonVersion: snapshot.latestDaemonVersion,
    );
  }

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async =>
      workspaces;

  @override
  Future<void> deleteWorkspace(String machineId,
      {required String workspaceId}) async {
    deletedWorkspaces.add((machineId, workspaceId));
    workspaces =
        workspaces.where((w) => w.id != workspaceId).toList(growable: false);
  }
}

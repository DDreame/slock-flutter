// =============================================================================
// #795 — ES locale completion regression
//
// Extends i18n_completion_test.dart coverage to validate EN↔ES key-set parity.
//
// Invariants verified:
//   INV-ES-PARITY-1: app_en.arb and app_es.arb have identical message key sets
//   INV-ES-PARITY-2: Newly added task/machine/workspace/screenshot keys exist
//                     in both EN and ES locales
//   INV-ES-PARITY-3: ES locale renders correctly (no fallback to EN) for
//                     representative newly-added keys
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-ES-PARITY-1: EN↔ES key-set parity
  // ---------------------------------------------------------------------------
  group('ES locale ARB key completeness', () {
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> esArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final esFile = File('lib/l10n/app_es.arb');
      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(esFile.existsSync(), isTrue, reason: 'app_es.arb must exist');
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      esArb = jsonDecode(esFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test(
        'app_en.arb and app_es.arb have matching message key sets '
        '(INV-ES-PARITY-1)', () {
      // Extract message keys: exclude @metadata keys and @@locale.
      final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
      final esKeys = esArb.keys.where((k) => !k.startsWith('@')).toSet();

      final enOnly = enKeys.difference(esKeys);
      final esOnly = esKeys.difference(enKeys);

      expect(enOnly, isEmpty,
          reason: 'Keys in app_en.arb but missing in app_es.arb: $enOnly');
      expect(esOnly, isEmpty,
          reason: 'Keys in app_es.arb but missing in app_en.arb: $esOnly');
      expect(enKeys.length, esKeys.length,
          reason: 'EN and ES must have identical key counts');
    });

    // -------------------------------------------------------------------------
    // INV-ES-PARITY-2: Spot-check newly added keys from #795
    // -------------------------------------------------------------------------
    test(
        'representative newly added task/machine/workspace/screenshot keys '
        'exist in ES (INV-ES-PARITY-2)', () {
      // Sample keys from each category added in this PR.
      const sampleKeys = [
        // Tasks
        'tasksHeaderTitle',
        'tasksEmptyAll',
        'tasksCreateTitle',
        'tasksCreateTitleLabel',
        'tasksSectionTodo',
        'tasksSectionInProgress',
        'tasksSectionInReview',
        'tasksSectionDone',
        'tasksSectionClosed',
        'tasksDeleteMessage',
        // Machines
        'machinesPageTitle',
        'machinesEmptyTitle',
        'machinesStatusOnline',
        'machinesStatusOffline',
        'machinesDeleteMessage',
        'machinesCopyApiKeyMessage',
        'machinesSummaryCount',
        // Workspaces
        'workspacesPageTitle',
        'workspacesDeleteTitle',
        'workspacesDeleteMessage',
        'workspacesStatusActive',
        // Screenshot
        'screenshotAnnotateTitle',
        'screenshotAnnotateExportError',
        'screenshotAnnotateSaveFailed',
      ];

      for (final key in sampleKeys) {
        expect(esArb.containsKey(key), isTrue,
            reason: 'app_es.arb missing key: $key');
        // Verify the ES value is non-empty (not just copied key name).
        final value = esArb[key];
        expect(value, isA<String>(),
            reason: 'app_es.arb[$key] must be a string');
        expect((value as String).isNotEmpty, isTrue,
            reason: 'app_es.arb[$key] must not be empty');
      }
    });

    // -------------------------------------------------------------------------
    // INV-ES-PARITY-2b: Verify ES values differ from EN for non-placeholder keys
    // (ensures actual translation, not copy-paste of English)
    // -------------------------------------------------------------------------
    test(
        'ES translations differ from EN for keyword-bearing keys '
        '(INV-ES-PARITY-2b)', () {
      // Pick keys whose Spanish translation should obviously differ from EN.
      const mustDifferKeys = [
        'tasksHeaderTitle',
        'tasksEmptyAll',
        'tasksSectionTodo',
        'tasksSectionInProgress',
        'machinesPageTitle',
        'machinesEmptyTitle',
        'machinesStatusOnline',
        'workspacesPageTitle',
        'screenshotAnnotateTitle',
      ];

      for (final key in mustDifferKeys) {
        final enVal = enArb[key] as String?;
        final esVal = esArb[key] as String?;
        expect(esVal, isNot(equals(enVal)),
            reason: 'app_es.arb[$key] should differ from EN value '
                '("$enVal") — appears untranslated');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // INV-ES-PARITY-3: ES locale render test — TasksPage
  // ---------------------------------------------------------------------------
  group('ES locale render', () {
    testWidgets(
      'TasksPage renders in es locale without overflow or missing-key fallback',
      (tester) async {
        final store = _FakeTasksStore(
          initialState: TasksState(
            status: TasksStatus.success,
            items: [
              _taskItem(id: 't1', status: 'todo'),
              _taskItem(id: 't2', status: 'in_progress'),
              _taskItem(id: 't3', status: 'in_review'),
              _taskItem(id: 't4', status: 'done'),
              _taskItem(id: 't5', status: 'closed'),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tasksStoreProvider.overrideWith(() => store),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const TasksPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Spanish locale resolved — the title should be "Tareas" not "Tasks".
        expect(find.text('Tareas'), findsOneWidget,
            reason: 'es locale should show Spanish "Tareas" title');

        // Verify all 5 status section keys rendered (proves no missing-key crash).
        expect(
          find.byKey(const ValueKey('task-section-todo')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-section-in_progress')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-section-in_review')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-section-done')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-section-closed')),
          findsOneWidget,
        );
      },
    );
  });
}

// -- Helpers ------------------------------------------------------------------

TaskItem _taskItem({
  String id = 'task-1',
  String status = 'todo',
  int taskNumber = 1,
}) {
  return TaskItem(
    id: id,
    taskNumber: taskNumber,
    title: 'Test task $id',
    status: status,
    channelId: 'channel-1',
    channelType: 'channel',
    createdById: 'user-1',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026, 5, 20),
  );
}

class _FakeTasksStore extends TasksStore {
  _FakeTasksStore({required TasksState initialState})
      : _initialState = initialState;

  final TasksState _initialState;

  @override
  TasksState build() => _initialState;

  @override
  Future<void> load() async {}

  @override
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {}
}

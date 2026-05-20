// =============================================================================
// #644 Phase A — i18n completion coverage
//
// Invariants verified:
// 1. app_en.arb and app_zh.arb have identical message key sets (no orphan keys)
// 2. All 13 new placeholder keys from this PR exist in both ARB files
// 3. TasksPage renders without overflow in zh locale
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
  // ARB key parity test
  // ---------------------------------------------------------------------------
  group('ARB key completeness', () {
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> zhArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final zhFile = File('lib/l10n/app_zh.arb');
      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
      expect(zhFile.existsSync(), isTrue, reason: 'app_zh.arb must exist');
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      zhArb = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('app_en.arb and app_zh.arb have matching message key sets', () {
      // Extract message keys: exclude @metadata keys and @@locale.
      final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
      final zhKeys = zhArb.keys.where((k) => !k.startsWith('@')).toSet();

      final enOnly = enKeys.difference(zhKeys);
      final zhOnly = zhKeys.difference(enKeys);

      expect(enOnly, isEmpty,
          reason: 'Keys in app_en.arb but missing in app_zh.arb: $enOnly');
      expect(zhOnly, isEmpty,
          reason: 'Keys in app_zh.arb but missing in app_en.arb: $zhOnly');
      expect(enKeys.length, zhKeys.length,
          reason: 'EN and ZH must have identical key counts');
    });

    test('all 13 new placeholder keys from PR #549 exist in both locales', () {
      const newKeys = [
        'machinesDeleteMessage',
        'machinesCopyApiKeyMessage',
        'machinesSummaryCount',
        'machinesSummaryOnline',
        'machinesApiKeyPrefix',
        'tasksDeleteMessage',
        'tasksAccessibilityTodo',
        'tasksAccessibilityInProgress',
        'tasksAccessibilityInReview',
        'tasksAccessibilityDone',
        'tasksAccessibilityClosed',
        'screenshotAnnotateExportError',
        'screenshotAnnotateSaveFailed',
      ];

      for (final key in newKeys) {
        expect(enArb.containsKey(key), isTrue,
            reason: 'app_en.arb missing key: $key');
        expect(zhArb.containsKey(key), isTrue,
            reason: 'app_zh.arb missing key: $key');
      }
    });

    test('placeholder keys have @metadata in app_en.arb', () {
      const placeholderKeys = [
        'machinesDeleteMessage',
        'machinesCopyApiKeyMessage',
        'machinesSummaryCount',
        'machinesSummaryOnline',
        'machinesApiKeyPrefix',
        'tasksDeleteMessage',
        'screenshotAnnotateExportError',
        'screenshotAnnotateSaveFailed',
      ];

      for (final key in placeholderKeys) {
        final metaKey = '@$key';
        expect(enArb.containsKey(metaKey), isTrue,
            reason: 'app_en.arb missing metadata key: $metaKey');
        final meta = enArb[metaKey] as Map<String, dynamic>;
        expect(meta.containsKey('placeholders'), isTrue,
            reason: '$metaKey must have placeholders defined');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // zh-locale render test — TasksPage
  // ---------------------------------------------------------------------------
  group('zh-locale render', () {
    testWidgets(
      'TasksPage renders in zh locale without overflow',
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
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: const TasksPage(serverId: 'server-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Chinese locale resolved — section headers use zh strings.
        expect(find.text('Tasks'), findsNothing,
            reason: 'zh locale should not show English "Tasks" title');

        // No FlutterError (overflow) should have been thrown.
        // If overflow occurs, pumpAndSettle would surface it as a test failure.

        // Verify all 5 status sections rendered without error.
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

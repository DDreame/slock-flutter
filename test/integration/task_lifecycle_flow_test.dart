// =============================================================================
// B132 Phase 2 — Integration Flow Test: Task lifecycle
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  testWidgets('message converts to task, then claim and status updates render',
      (tester) async {
    final prefs = await b132Prefs();
    final conversationRepository = B132ConversationRepository();
    conversationRepository.sendCompleter = Completer<void>();
    final tasksRepository = B132TasksRepository();

    final router = GoRouter(
      initialLocation: '/conversation',
      routes: [
        GoRoute(
          path: '/conversation',
          builder: (_, __) => ConversationDetailPage(target: b132ChannelTarget),
        ),
        GoRoute(
          path: '/servers/:serverId/tasks',
          builder: (_, state) => TasksPage(
            serverId: state.pathParameters['serverId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      conversationRepository: conversationRepository,
      tasksRepository: tasksRepository,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'Turn this into a task',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pump();

    expect(find.text('Turn this into a task'), findsWidgets);
    expect(
      find.byKey(const ValueKey('pending-sending-indicator')),
      findsOneWidget,
    );

    conversationRepository.completeSend();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pending-sending-indicator')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('message-sent-1')), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('message-sent-1')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('ctx-action-create-task')));
    await tester.tap(find.byKey(const ValueKey('ctx-action-create-task')));
    await tester.pumpAndSettle();

    expect(tasksRepository.convertedMessageIds, ['sent-1']);

    router.go('/servers/server-1/tasks');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-task-from-sent-1')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('task-actions-task-from-sent-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-action-claim')));
    await tester.pumpAndSettle();

    expect(tasksRepository.claimedTaskIds, ['task-from-sent-1']);
    expect(
      find.byKey(const ValueKey('task-assignee-task-from-sent-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('task-actions-task-from-sent-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-action-start')));
    await tester.pumpAndSettle();

    expect(tasksRepository.statusUpdates['task-from-sent-1'], 'in_progress');
    expect(find.textContaining('In Progress'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('task-actions-task-from-sent-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-action-done')));
    await tester.pumpAndSettle();

    expect(tasksRepository.statusUpdates['task-from-sent-1'], 'done');
    expect(
      find.byKey(const ValueKey('task-row-opacity-task-from-sent-1')),
      findsOneWidget,
    );
  });
}

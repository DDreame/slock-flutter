// =============================================================================
// #832 — L10n Load-Bearing Tests
//
// Invariants verified (all use ZH locale — reverting to hardcoded English → RED):
// INV-832-L10N-1: HomeDirectMessageRow agent badge uses l10n.dmAgentBadge
// INV-832-L10N-2: TaskStatusOverlay status labels use l10n.taskStatusTodo/etc.
// INV-832-L10N-3: MemberListItem role badges use l10n.membersRoleOwner/Admin/Member
// INV-832-L10N-4: TaskStatusOverlay overlay text uses l10n keys
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/tasks/presentation/widgets/task_status_overlay.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-832-L10N-1: DM agent badge renders l10n.dmAgentBadge in ZH
  // ---------------------------------------------------------------------------
  group('INV-832-L10N-1: DM agent badge l10n', () {
    testWidgets(
      'HomeDirectMessageRow shows ZH agent badge text (智能体), not English',
      (tester) async {
        const dm = HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'dm-1',
          ),
          title: 'Bot Alpha',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider
                  .overrideWith((ref) => Stream.value(DateTime.now())),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: HomeDirectMessageRow(
                  directMessage: dm,
                  isAgent: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Positive: ZH badge text must be present.
        expect(find.text('智能体'), findsOneWidget);

        // Negative: hardcoded English must NOT appear.
        expect(find.text('AGENT'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-832-L10N-2: TaskStatusOverlay status labels in ZH
  // ---------------------------------------------------------------------------
  group('INV-832-L10N-2: TaskStatusOverlay status labels l10n', () {
    testWidgets(
      'renders all 4 status labels in ZH locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH status labels must be present.
        // Note: 进行中 and 已完成 appear as both label AND description in ZH.
        expect(find.text('待办'), findsOneWidget);
        expect(find.text('进行中'), findsAtLeast(1));
        expect(find.text('审核中'), findsOneWidget);
        expect(find.text('已完成'), findsAtLeast(1));

        // Negative: hardcoded English must NOT appear.
        expect(find.text('Todo'), findsNothing);
        expect(find.text('In Progress'), findsNothing);
        expect(find.text('In Review'), findsNothing);
        expect(find.text('Done'), findsNothing);
      },
    );

    testWidgets(
      'renders status descriptions in ZH locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH status descriptions for non-current zones.
        // "todo" is current, so its description is replaced by "当前" badge.
        // Note: 进行中 appears as both label and description (same ZH text).
        expect(find.text('进行中'), findsAtLeast(1));
        expect(find.text('需要审核'), findsOneWidget); // in_review description
        expect(find.text('已完成'), findsAtLeast(1)); // done label/description

        // Negative: hardcoded English descriptions must NOT appear.
        expect(find.text('Not started'), findsNothing);
        expect(find.text('Working on it'), findsNothing);
        expect(find.text('Needs review'), findsNothing);
        expect(find.text('Completed'), findsNothing);
      },
    );

    testWidgets(
      'renders overlay chrome text in ZH locale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH overlay title and hints.
        expect(find.text('拖放以更改状态'), findsOneWidget);
        expect(find.text('在方框外释放以取消'), findsOneWidget);
        expect(find.text('当前'), findsOneWidget); // current badge on "todo"

        // Negative: hardcoded English chrome must NOT appear.
        expect(find.text('Drop to change status'), findsNothing);
        expect(find.text('Release outside boxes to cancel'), findsNothing);
        expect(find.text('Current'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-832-L10N-3: MemberListItem role badges in ZH
  // ---------------------------------------------------------------------------
  group('INV-832-L10N-3: MemberListItem role badges l10n', () {
    testWidgets(
      'renders Owner role badge in ZH (所有者)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              presenceStoreProvider.overrideWith(
                () => _FakePresenceStore(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MemberListItem(
                  member: const MemberProfile(
                    id: 'user-1',
                    displayName: 'Alice',
                    role: 'owner',
                    username: 'alice',
                  ),
                  canManageMember: false,
                  onTap: () {},
                  onMessage: () {},
                  onChangeRole: (_) {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH role label.
        expect(find.text('所有者'), findsOneWidget);

        // Negative: hardcoded English must NOT appear.
        expect(find.text('Owner'), findsNothing);
      },
    );

    testWidgets(
      'renders Admin role badge in ZH (管理员)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              presenceStoreProvider.overrideWith(
                () => _FakePresenceStore(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MemberListItem(
                  member: const MemberProfile(
                    id: 'user-2',
                    displayName: 'Bob',
                    role: 'admin',
                    username: 'bob',
                  ),
                  canManageMember: false,
                  onTap: () {},
                  onMessage: () {},
                  onChangeRole: (_) {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH role label.
        expect(find.text('管理员'), findsOneWidget);

        // Negative: hardcoded English must NOT appear.
        expect(find.text('Admin'), findsNothing);
      },
    );

    testWidgets(
      'renders Member role badge in ZH (成员)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              presenceStoreProvider.overrideWith(
                () => _FakePresenceStore(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MemberListItem(
                  member: const MemberProfile(
                    id: 'user-3',
                    displayName: 'Charlie',
                    role: 'member',
                    username: 'charlie',
                  ),
                  canManageMember: false,
                  onTap: () {},
                  onMessage: () {},
                  onChangeRole: (_) {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Positive: ZH role label.
        expect(find.text('成员'), findsOneWidget);

        // Negative: hardcoded English must NOT appear.
        expect(find.text('Member'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-832-L10N-4: DM context menu actions in ZH
  // ---------------------------------------------------------------------------
  group('INV-832-L10N-4: DM context menu l10n', () {
    testWidgets(
      'HomeDirectMessageRow action sheet labels render in ZH on long press',
      (tester) async {
        const dm = HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'dm-2',
          ),
          title: 'Alice',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider
                  .overrideWith((ref) => Stream.value(DateTime.now())),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: HomeDirectMessageRow(
                  directMessage: dm,
                  isAgent: false,
                  onTap: () {},
                  onTogglePin: () {},
                  onMarkAsUnread: () {},
                  onHide: () {},
                  onMoveUp: () {},
                  onMoveDown: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Long press to open action sheet.
        await tester.longPress(find.byType(HomeDirectMessageRow));
        await tester.pumpAndSettle();

        // Positive: ZH action labels.
        expect(find.text('上移'), findsOneWidget);
        expect(find.text('下移'), findsOneWidget);
        expect(find.text('置顶对话'), findsOneWidget);
        expect(find.text('标为未读'), findsOneWidget);
        expect(find.text('关闭对话'), findsOneWidget);

        // Negative: hardcoded English must NOT appear.
        expect(find.text('Move up'), findsNothing);
        expect(find.text('Move down'), findsNothing);
        expect(find.text('Pin conversation'), findsNothing);
        expect(find.text('Mark as Unread'), findsNothing);
        expect(find.text('Close conversation'), findsNothing);
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakePresenceStore extends AutoDisposeNotifier<PresenceState>
    implements PresenceStore {
  @override
  PresenceState build() => const PresenceState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

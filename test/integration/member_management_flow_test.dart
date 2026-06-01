// =============================================================================
// B132 Phase 2 — Integration Flow Test: Member management
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/channels/presentation/page/channel_members_page.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  testWidgets('add channel member, then change workspace member role',
      (tester) async {
    final prefs = await b132Prefs();
    final channelMemberRepository = B132ChannelMemberRepository(members: []);
    final memberRepository = B132MemberRepository();

    final router = GoRouter(
      initialLocation: '/servers/server-1/channels/general/members',
      routes: [
        GoRoute(
          path: '/servers/:serverId/channels/:channelId/members',
          builder: (_, state) => ChannelMembersPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
        GoRoute(
          path: '/servers/:serverId/members',
          builder: (_, state) => MembersPage(
            serverId: state.pathParameters['serverId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      channelMemberRepository: channelMemberRepository,
      memberRepository: memberRepository,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('channel-members-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('Bob'),
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.add_circle_outline),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(channelMemberRepository.members.any((m) => m.userId == 'user-2'),
        isTrue);

    router.go('/servers/server-1/members');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('member-role-user-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-actions-user-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('members-role-option-admin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('members-change-role-confirm')));
    await tester.pumpAndSettle();

    expect(memberRepository.members.firstWhere((m) => m.id == 'user-2').role,
        'admin');
    expect(find.text('Admin'), findsWidgets);
  });
}

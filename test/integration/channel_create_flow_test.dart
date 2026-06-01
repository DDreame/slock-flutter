// =============================================================================
// B132 Phase 2 — Integration Flow Test: Channel create → first message
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/channels/presentation/page/channels_tab_page.dart';
import 'package:slock_app/features/channels/presentation/page/channel_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  testWidgets('create channel, open it, and send first message',
      (tester) async {
    final prefs = await b132Prefs();
    final homeRepository = B132HomeRepository(channels: []);
    final conversationRepository = B132ConversationRepository();
    final channelManagementRepository = B132ChannelManagementRepository(
      onCreated: homeRepository.addChannel,
    );

    final router = GoRouter(
      initialLocation: '/channels',
      routes: [
        GoRoute(
          path: '/channels',
          builder: (_, __) => const ChannelsTabPage(),
        ),
        GoRoute(
          path: '/servers/:serverId/channels/:channelId',
          builder: (_, state) => ChannelPage(
            serverId: state.pathParameters['serverId']!,
            channelId: state.pathParameters['channelId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      homeRepository: homeRepository,
      conversationRepository: conversationRepository,
      channelManagementRepository: channelManagementRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('channels-tab-create-button')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('channels-tab-create-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-channel-name')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('create-channel-name')),
      'Launch',
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('create-channel-submit')));
    await tester.tap(find.byKey(const ValueKey('create-channel-submit')));
    await tester.pumpAndSettle();

    expect(channelManagementRepository.createdNames, ['Launch']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/channels');
    final createdChannelRow = find.byKey(const ValueKey('channels-tab-launch'));
    expect(createdChannelRow, findsOneWidget);
    final createdChannelInkWell = find.ancestor(
      of: find.text('Launch'),
      matching: find.byType(InkWell),
    );
    expect(createdChannelInkWell, findsOneWidget);

    await tester.tap(createdChannelInkWell);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conversation-empty')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'First channel message',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-send')).hitTestable());
    await tester.pumpAndSettle();

    expect(conversationRepository.sentContents, ['First channel message']);
    expect(find.text('First channel message'), findsOneWidget);
  });
}

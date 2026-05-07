import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  Widget buildRow({
    required HomeDirectMessageSummary dm,
    bool isAgent = false,
    bool isOnline = false,
    int unreadCount = 0,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: HomeDirectMessageRow(
          directMessage: dm,
          isAgent: isAgent,
          isOnline: isOnline,
          unreadCount: unreadCount,
          onTap: () {},
        ),
      ),
    );
  }

  group('HomeDirectMessageRow agent badge', () {
    testWidgets('shows AGENT badge when isAgent is true', (tester) async {
      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Bot Alpha',
      );

      await tester.pumpWidget(buildRow(dm: dm, isAgent: true));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dm-agent-badge')),
        findsOneWidget,
      );
    });

    testWidgets('does not show AGENT badge when isAgent is false', (
      tester,
    ) async {
      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-2'),
        title: 'Alice',
      );

      await tester.pumpWidget(buildRow(dm: dm, isAgent: false));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dm-agent-badge')),
        findsNothing,
      );
    });

    testWidgets('agent badge renders robot icon', (tester) async {
      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-3'),
        title: 'Bot Beta',
      );

      await tester.pumpWidget(buildRow(dm: dm, isAgent: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });
  });

  group('HomeDirectMessageSummary isAgent field', () {
    test('defaults to false', () {
      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Alice',
      );
      expect(dm.isAgent, false);
    });

    test('can be set to true', () {
      const dm = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Bot',
        isAgent: true,
      );
      expect(dm.isAgent, true);
    });

    test('equality includes isAgent', () {
      const dm1 = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Bot',
        isAgent: true,
      );
      const dm2 = HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Bot',
        isAgent: false,
      );
      expect(dm1, isNot(equals(dm2)));
    });
  });
}

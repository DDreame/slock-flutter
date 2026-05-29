// =============================================================================
// B123 PR 3 — Mention tap → profile navigation (load-bearing tests).
//
// Tests prove:
// 1. MentionBuilder with onMentionTap wraps chip in GestureDetector that fires.
// 2. buildMentionAwareSpan with onMentionTap attaches TapGestureRecognizer.
// 3. Tapping mention in MarkdownMessageBody fires onMentionTap callback.
// 4. Callback receives correct mention name (without @ prefix).
// 5. resolveMentionProfileRoute resolves handle → correct profile route.
// 6. resolveMentionProfileRoute returns null for unresolvable handle (no-op).
// 7. resolveMentionProfileRoute is case-insensitive on handle matching.
//
// Reverting mention-tap feature → tests RED.
// =============================================================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/conversation/presentation/utils/mention_profile_resolver.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MentionBuilder — GestureDetector wrapping (widget tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — MentionBuilder onMentionTap', () {
    testWidgets('fires callback with mention name when chip is tapped',
        (tester) async {
      String? tappedName;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hello @Alice how are you?',
            onMentionTap: (name) => tappedName = name,
          ),
        ),
      ));

      // Find the mention GestureDetector by key.
      final mentionTap = find.byKey(const ValueKey('mention-tap-Alice'));
      expect(
        mentionTap,
        findsOneWidget,
        reason: 'Reverting onMentionTap → no GestureDetector rendered → RED.',
      );

      await tester.tap(mentionTap);
      await tester.pumpAndSettle();

      expect(
        tappedName,
        'Alice',
        reason: 'Callback must receive mention name without @ prefix.',
      );
    });

    testWidgets('does not wrap in GestureDetector when onMentionTap is null',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: MarkdownMessageBody(
            content: 'Hello @Bob world',
          ),
        ),
      ));

      expect(
        find.byKey(const ValueKey('mention-tap-Bob')),
        findsNothing,
        reason: 'When onMentionTap is null, no GestureDetector key exists.',
      );
    });

    testWidgets('fires correct name for multiple mentions', (tester) async {
      final tapped = <String>[];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hey @Alice and @Bob!',
            onMentionTap: (name) => tapped.add(name),
          ),
        ),
      ));

      // Tap Alice
      await tester.tap(find.byKey(const ValueKey('mention-tap-Alice')));
      await tester.pumpAndSettle();

      // Tap Bob
      await tester.tap(find.byKey(const ValueKey('mention-tap-Bob')));
      await tester.pumpAndSettle();

      expect(tapped, ['Alice', 'Bob']);
    });
  });

  // ---------------------------------------------------------------------------
  // buildMentionAwareSpan — TapGestureRecognizer (unit tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — buildMentionAwareSpan onMentionTap', () {
    test('attaches TapGestureRecognizer to mention spans', () {
      String? tappedName;

      final span = buildMentionAwareSpan(
        text: 'Hello @Alice world',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
        onMentionTap: (name) => tappedName = name,
      );

      // Find the mention span with recognizer.
      final children = span.children!;
      final mentionSpan = children.whereType<TextSpan>().firstWhere(
            (s) => s.recognizer != null,
          );

      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());

      // Fire the recognizer.
      (mentionSpan.recognizer as TapGestureRecognizer).onTap!();
      expect(
        tappedName,
        'Alice',
        reason:
            'Reverting onMentionTap in buildMentionAwareSpan → no recognizer → RED.',
      );
    });

    test('does not attach recognizer when onMentionTap is null', () {
      final span = buildMentionAwareSpan(
        text: 'Hello @Alice world',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
      );

      final children = span.children!;
      final hasRecognizer =
          children.whereType<TextSpan>().any((s) => s.recognizer != null);

      expect(hasRecognizer, isFalse,
          reason: 'No recognizer when onMentionTap is null.');
    });

    test('populates createdRecognizers list for lifecycle management', () {
      final recognizers = <GestureRecognizer>[];

      buildMentionAwareSpan(
        text: '@Alice and @Bob',
        baseStyle: const TextStyle(),
        mentionColor: Colors.blue,
        mentionBackground: Colors.blue.withValues(alpha: 0.1),
        selfMentionColor: Colors.white,
        selfMentionBackground: Colors.blue,
        onMentionTap: (_) {},
        createdRecognizers: recognizers,
      );

      expect(
        recognizers.length,
        2,
        reason:
            'Reverting createdRecognizers support → recognizers leak → RED.',
      );
      // Clean up.
      for (final r in recognizers) {
        r.dispose();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // resolveMentionProfileRoute — production navigation (unit tests)
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — resolveMentionProfileRoute', () {
    test('resolves known human member to correct profile route', () async {
      final repo = _FakeChannelMemberRepository(members: [
        const ChannelMember(
          id: 'member-1',
          channelId: 'ch-1',
          userId: 'user-abc',
          userName: 'Alice',
        ),
        const ChannelMember(
          id: 'member-2',
          channelId: 'ch-1',
          userId: 'user-def',
          userName: 'Bob',
        ),
      ]);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-1'),
        channelId: 'ch-1',
        mentionName: 'Alice',
      );

      expect(
        route,
        '/servers/server-1/profile/user-abc',
        reason:
            'Reverting resolveMentionProfileRoute → wrong route or null → RED.',
      );
    });

    test('resolves known agent member to correct profile route', () async {
      final repo = _FakeChannelMemberRepository(members: [
        const ChannelMember(
          id: 'member-1',
          channelId: 'ch-1',
          agentId: 'agent-xyz',
          agentName: 'BotHelper',
        ),
      ]);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-2'),
        channelId: 'ch-1',
        mentionName: 'BotHelper',
      );

      expect(route, '/servers/server-2/profile/agent-xyz');
    });

    test('returns null for unresolvable handle (graceful no-op)', () async {
      final repo = _FakeChannelMemberRepository(members: [
        const ChannelMember(
          id: 'member-1',
          channelId: 'ch-1',
          userId: 'user-abc',
          userName: 'Alice',
        ),
      ]);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-1'),
        channelId: 'ch-1',
        mentionName: 'UnknownPerson',
      );

      expect(
        route,
        isNull,
        reason: 'Unresolvable mention must return null (no-op), not throw.',
      );
    });

    test('returns null when member has no entity ID', () async {
      final repo = _FakeChannelMemberRepository(members: [
        const ChannelMember(
          id: 'member-1',
          channelId: 'ch-1',
          // No userId, no agentId — memberEntityId is null.
          userName: 'Ghost',
        ),
      ]);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-1'),
        channelId: 'ch-1',
        mentionName: 'Ghost',
      );

      expect(route, isNull);
    });

    test('matching is case-insensitive', () async {
      final repo = _FakeChannelMemberRepository(members: [
        const ChannelMember(
          id: 'member-1',
          channelId: 'ch-1',
          userId: 'user-abc',
          userName: 'Alice',
        ),
      ]);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-1'),
        channelId: 'ch-1',
        mentionName: 'alice', // lowercase
      );

      expect(
        route,
        '/servers/server-1/profile/user-abc',
        reason: 'Case-insensitive match must still resolve.',
      );
    });

    test('returns null when member list is empty', () async {
      final repo = _FakeChannelMemberRepository(members: []);

      final route = await resolveMentionProfileRoute(
        memberRepo: repo,
        serverId: const ServerScopeId('server-1'),
        channelId: 'ch-1',
        mentionName: 'Alice',
      );

      expect(route, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // MarkdownMessageBody — onMentionTap integration
  // ---------------------------------------------------------------------------
  group('B123 PR 3 — MarkdownMessageBody onMentionTap integration', () {
    testWidgets('self-mention is tappable and fires callback', (tester) async {
      String? tappedName;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MarkdownMessageBody(
            content: 'Hey @CurrentUser check this',
            currentUserName: 'CurrentUser',
            onMentionTap: (name) => tappedName = name,
          ),
        ),
      ));

      // Self-mention should still be tappable.
      final mentionTap = find.byKey(const ValueKey('mention-tap-CurrentUser'));
      expect(mentionTap, findsOneWidget);

      await tester.tap(mentionTap);
      await tester.pumpAndSettle();

      expect(tappedName, 'CurrentUser');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  _FakeChannelMemberRepository({required this.members});

  final List<ChannelMember> members;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}

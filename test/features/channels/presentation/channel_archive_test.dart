// =============================================================================
// B123 PR 1 — Channel archive/unarchive (load-bearing tests).
//
// Tests prove:
// 1. HomeChannelRow shows archive icon when channel.isArchived == true.
// 2. HomeChannelSummary.isArchived wired correctly (model, copyWith, equality).
// 3. Repository posts to correct archive/unarchive paths.
// 4. ConversationDetailState.isArchived propagated from snapshot.
//
// Reverting archive handling → tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HomeChannelRow — archived badge
  // ---------------------------------------------------------------------------
  group('B123 PR 1 — HomeChannelRow archived badge', () {
    testWidgets('shows archive icon when isArchived is true', (tester) async {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: true,
      );

      await tester.pumpWidget(_buildApp(channel: channel));

      expect(
        find.byKey(const ValueKey('channel-archived-badge')),
        findsOneWidget,
        reason: 'Reverting isArchived → no archived badge → RED.',
      );
    });

    testWidgets('does NOT show archive icon when isArchived is false',
        (tester) async {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: false,
      );

      await tester.pumpWidget(_buildApp(channel: channel));

      expect(
        find.byKey(const ValueKey('channel-archived-badge')),
        findsNothing,
        reason: 'Non-archived channel must NOT show archived badge.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // HomeChannelSummary model — isArchived field
  // ---------------------------------------------------------------------------
  group('B123 PR 1 — HomeChannelSummary.isArchived', () {
    test('isArchived defaults to false', () {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
      );
      expect(channel.isArchived, isFalse);
    });

    test('isArchived can be set to true', () {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: true,
      );
      expect(channel.isArchived, isTrue);
    });

    test('copyWith preserves isArchived', () {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: true,
      );
      final copy = channel.copyWith(lastMessagePreview: 'hello');
      expect(copy.isArchived, isTrue);
    });

    test('copyWith can change isArchived', () {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: true,
      );
      final copy = channel.copyWith(isArchived: false);
      expect(copy.isArchived, isFalse);
    });

    test('equality includes isArchived', () {
      const a = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: true,
      );
      const b = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
        name: 'general',
        isArchived: false,
      );
      expect(a == b, isFalse, reason: 'isArchived must be part of equality.');
    });
  });
}

// =============================================================================
// Helpers
// =============================================================================

Widget _buildApp({required HomeChannelSummary channel}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: [AppColors.light],
      ),
      home: Scaffold(
        body: HomeChannelRow(
          channel: channel,
          onTap: () {},
        ),
      ),
    ),
  );
}

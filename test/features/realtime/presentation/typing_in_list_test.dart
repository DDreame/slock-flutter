import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/realtime/application/list_typing_indicator_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// #578: Typing Indicator in List Rows — Phase A (test-only)
//
// Tests for per-channel typing indicators displayed in channel/DM list rows.
// The existing typing indicator infrastructure is page-scoped (single global
// store). Phase B refactors to a family-keyed store with a global WebSocket
// listener so list rows can show typing status without opening the chat.
//
// Invariants verified:
// T1: ListTypingIndicatorStore is keyed per channel (family provider)
// T2: Channel list row shows typing text when someone is typing
// T3: Typing indicator clears after timeout (5s)
// T4: Multiple typers show combined text
// T5: DM list row also shows typing indicator
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  // Scope keys matching the format used by the realtime layer.
  const channelScopeKey = 'server:server-1/channel:ch-general';
  const channelScopeKey2 = 'server:server-1/channel:ch-random';

  // -------------------------------------------------------------------------
  // T1: ListTypingIndicatorStore is keyed per channel (family)
  // -------------------------------------------------------------------------
  test(
    'ListTypingIndicatorStore maintains independent state per scope key',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read two different family instances — both should build without error
      // and produce independent initial states.
      final state1 =
          container.read(listTypingIndicatorStoreProvider(channelScopeKey));
      final state2 =
          container.read(listTypingIndicatorStoreProvider(channelScopeKey2));

      // Both should have initial state (no typing).
      expect(
        state1.isActive,
        isFalse,
        reason: 'Initial state for channel 1 should have no active typers',
      );
      expect(
        state2.isActive,
        isFalse,
        reason: 'Initial state for channel 2 should have no active typers',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Channel list row shows typing text when someone is typing
  // -------------------------------------------------------------------------
  testWidgets(
    'Channel list row shows typing text when someone is typing',
    (tester) async {
      final channel = HomeChannelSummary(
        scopeId: const ChannelScopeId(serverId: serverId, value: 'ch-general'),
        name: 'general',
        lastMessagePreview: 'Last message here',
        lastActivityAt: DateTime.utc(2026, 5, 18, 10, 0),
      );

      // Pump a channel row with an active typing state for its scope key.
      // Phase B makes HomeChannelRow a ConsumerWidget that watches the
      // listTypingIndicatorStoreProvider for its channel. For now, just
      // verify the key/widget structure exists.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HomeChannelRow(
                channel: channel,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The typing indicator widget must exist in the row.
      // Phase B adds a ValueKey('channel-row-typing-indicator') widget that
      // conditionally replaces the preview text when typing is active.
      expect(
        find.byKey(const ValueKey('channel-row-typing-indicator')),
        findsOneWidget,
        reason: 'Channel list row must contain a typing indicator widget '
            'that can conditionally show typing status',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: Typing indicator clears after timeout (5s)
  // -------------------------------------------------------------------------
  test(
    'Typing indicator clears after 5-second timeout',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Access the notifier for the channel scope key.
      final notifier = container
          .read(listTypingIndicatorStoreProvider(channelScopeKey).notifier);

      // Simulate a typing event arriving.
      notifier.addTyper(userId: 'user-alice', displayName: 'Alice');

      // Immediately after adding, typing should be active.
      final stateAfterAdd =
          container.read(listTypingIndicatorStoreProvider(channelScopeKey));
      expect(
        stateAfterAdd.isActive,
        isTrue,
        reason: 'After addTyper, the indicator should be active',
      );
      expect(
        stateAfterAdd.typerNames,
        ['Alice'],
        reason: 'Display text should show the typer name',
      );

      // Wait for the 5-second expiry.
      await Future<void>.delayed(const Duration(seconds: 6));

      final stateAfterExpiry =
          container.read(listTypingIndicatorStoreProvider(channelScopeKey));
      expect(
        stateAfterExpiry.isActive,
        isFalse,
        reason: 'After 5-second timeout, typing indicator must clear',
      );
      expect(
        stateAfterExpiry.typerNames,
        isEmpty,
        reason: 'Typer names must be empty after timeout clears the typer',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: Multiple typers show combined text
  // -------------------------------------------------------------------------
  test(
    'Multiple typers show combined text',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container
          .read(listTypingIndicatorStoreProvider(channelScopeKey).notifier);

      // Add two typers.
      notifier.addTyper(userId: 'user-alice', displayName: 'Alice');
      notifier.addTyper(userId: 'user-bob', displayName: 'Bob');

      final state =
          container.read(listTypingIndicatorStoreProvider(channelScopeKey));
      expect(
        state.typerNames,
        ['Alice', 'Bob'],
        reason: 'Two typers must show both names',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: DM list row also shows typing indicator
  // -------------------------------------------------------------------------
  testWidgets(
    'DM list row shows typing indicator',
    (tester) async {
      final dm = HomeDirectMessageSummary(
        scopeId:
            const DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
        title: 'Alice',
        lastMessagePreview: 'Hey there!',
        lastActivityAt: DateTime.utc(2026, 5, 18, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HomeDirectMessageRow(
                directMessage: dm,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // DM row must contain typing indicator widget.
      expect(
        find.byKey(const ValueKey('dm-row-typing-indicator')),
        findsOneWidget,
        reason: 'DM list row must contain a typing indicator widget '
            'that can conditionally show typing status',
      );
    },
  );
}

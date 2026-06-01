// =============================================================================
// #654 — DM Presence Map Lookup Phase A
//
// Invariants verified:
// INV-DM-MAP-1: dmScopeMapProvider includes DMs from all 3 source lists
//               (pinned, regular, hidden).
// INV-DM-MAP-2: dmScopeMapProvider recomputes when DM lists change.
// INV-DM-MAP-3: dmScopeMapProvider does NOT recompute when unrelated
//               state changes (isRefreshing, taskCount).
// INV-DM-MAP-4: O(1) lookup returns correct peerId for a given scopeId.
// INV-DM-MAP-5: Production _DmPresenceSubtitle renders presence status
//               text from dmScopeMapProvider lookup (integration).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/dm_scope_map_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  const serverId = ServerScopeId('server-1');

  HomeDirectMessageSummary makeDm(String id, {String? peerId}) {
    return HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(serverId: serverId, value: id),
      title: 'DM $id',
      peerId: peerId ?? 'peer-$id',
    );
  }

  // ---------------------------------------------------------------------------
  // INV-DM-MAP-1: Map includes DMs from all 3 source lists
  // ---------------------------------------------------------------------------
  test(
    'INV-DM-MAP-1: dmScopeMapProvider includes DMs from pinned, regular, '
    'and hidden lists',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          pinnedDirectMessages: [makeDm('dm-pinned', peerId: 'peer-pinned')],
          directMessages: [makeDm('dm-regular', peerId: 'peer-regular')],
          hiddenDirectMessages: [makeDm('dm-hidden', peerId: 'peer-hidden')],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
        ],
      );
      addTearDown(container.dispose);

      final map = container.read(dmScopeMapProvider);

      expect(map['dm-pinned']?.peerId, 'peer-pinned');
      expect(map['dm-regular']?.peerId, 'peer-regular');
      expect(map['dm-hidden']?.peerId, 'peer-hidden');
      expect(map.length, 3);
    },
  );

  // ---------------------------------------------------------------------------
  // INV-DM-MAP-2: Recomputes when DM lists change
  // ---------------------------------------------------------------------------
  test(
    'INV-DM-MAP-2: dmScopeMapProvider recomputes when DM list changes',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          directMessages: [makeDm('dm-1')],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
        ],
      );
      addTearDown(container.dispose);

      final mapA = container.read(dmScopeMapProvider);
      expect(mapA.containsKey('dm-1'), isTrue);
      expect(mapA.containsKey('dm-2'), isFalse);

      // Add a new DM.
      store.emitDmChange([makeDm('dm-1'), makeDm('dm-2')]);

      final mapB = container.read(dmScopeMapProvider);
      expect(mapB.containsKey('dm-2'), isTrue);
      expect(mapB.length, 2);
      expect(
        identical(mapA, mapB),
        isFalse,
        reason: 'Map must recompute when DM list changes (INV-DM-MAP-2)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-DM-MAP-3: Does NOT recompute on unrelated state changes
  // ---------------------------------------------------------------------------
  test(
    'INV-DM-MAP-3: dmScopeMapProvider does NOT recompute on '
    'unrelated state changes',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          directMessages: [makeDm('dm-1')],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
        ],
      );
      addTearDown(container.dispose);

      final mapA = container.read(dmScopeMapProvider);

      // Emit non-DM change (isRefreshing toggle).
      store.emitNonDmChange();

      final mapB = container.read(dmScopeMapProvider);
      expect(
        identical(mapA, mapB),
        isTrue,
        reason: 'Map must NOT recompute when only non-DM state changes '
            '(INV-DM-MAP-3)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // INV-DM-MAP-4: O(1) lookup returns correct peerId
  // ---------------------------------------------------------------------------
  test(
    'INV-DM-MAP-4: map lookup returns correct peerId by scopeId value',
    () {
      final store = _FakeHomeListStore(
        initialState: HomeListState(
          status: HomeListStatus.success,
          pinnedDirectMessages: [
            makeDm('dm-a', peerId: 'peer-alice'),
          ],
          directMessages: [
            makeDm('dm-b', peerId: 'peer-bob'),
            makeDm('dm-c', peerId: 'peer-charlie'),
          ],
          hiddenDirectMessages: [
            makeDm('dm-d', peerId: 'peer-dave'),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          homeListStoreProvider.overrideWith(() => store),
        ],
      );
      addTearDown(container.dispose);

      final map = container.read(dmScopeMapProvider);

      // O(1) lookups.
      expect(map['dm-a']?.peerId, 'peer-alice');
      expect(map['dm-b']?.peerId, 'peer-bob');
      expect(map['dm-c']?.peerId, 'peer-charlie');
      expect(map['dm-d']?.peerId, 'peer-dave');
      // Non-existent key returns null.
      expect(map['dm-nonexistent'], isNull);
    },
  );

  // ---------------------------------------------------------------------------
  // INV-DM-MAP-5: Production _DmPresenceSubtitle renders from map lookup
  // ---------------------------------------------------------------------------
  group(
    'INV-DM-MAP-5: production _DmPresenceSubtitle renders via '
    'dmScopeMapProvider',
    () {
      late SharedPreferences prefs;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      testWidgets(
        'shows "Online" text when peer is online via map-based lookup',
        (tester) async {
          const dmScopeId =
              DirectMessageScopeId(serverId: serverId, value: 'dm-conv-1');
          final dmTarget = ConversationDetailTarget.directMessage(dmScopeId);

          final convStore = _FakeConversationDetailStore(target: dmTarget);
          final homeStore = _FakeHomeListStore(
            initialState: HomeListState(
              status: HomeListStatus.success,
              directMessages: [
                const HomeDirectMessageSummary(
                  scopeId: dmScopeId,
                  title: 'Alice',
                  peerId: 'user-alice',
                ),
              ],
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                conversationDetailStoreProvider.overrideWith(() => convStore),
                conversationDetailSessionStoreProvider
                    .overrideWithValue(ConversationDetailSessionCache()),
                voiceMessageStoreProvider
                    .overrideWith(() => _FakeVoiceMessageStore()),
                sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
                homeListStoreProvider.overrideWith(() => homeStore),
                sharedPreferencesProvider.overrideWithValue(prefs),
                realtimeReductionIngressProvider
                    .overrideWithValue(RealtimeReductionIngress()),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                home: ConversationDetailPage(
                  target: dmTarget,
                  registerOpenTarget: false,
                ),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Set peer online AFTER widget builds (simulates realtime event).
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ConversationDetailPage)),
          );
          container
              .read(presenceStoreProvider.notifier)
              .setOnline('user-alice');
          await tester.pumpAndSettle();

          // The real _DmPresenceSubtitle should show "Online" from the
          // dmScopeMapProvider lookup path.
          expect(
            find.byKey(const ValueKey('conversation-dm-presence')),
            findsOneWidget,
            reason: 'Presence subtitle widget must be rendered for DM',
          );
          expect(
            find.text('Online'),
            findsOneWidget,
            reason: 'Presence subtitle must show "Online" via '
                'dmScopeMapProvider lookup (INV-DM-MAP-5)',
          );
        },
      );

      testWidgets(
        'shows nothing when DM is not in map (no peerId)',
        (tester) async {
          const dmScopeId =
              DirectMessageScopeId(serverId: serverId, value: 'dm-unknown');
          final dmTarget = ConversationDetailTarget.directMessage(dmScopeId);

          final convStore = _FakeConversationDetailStore(target: dmTarget);
          // Home state has NO DMs — map lookup returns null.
          final homeStore = _FakeHomeListStore(
            initialState: HomeListState(
              status: HomeListStatus.success,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                conversationDetailStoreProvider.overrideWith(() => convStore),
                conversationDetailSessionStoreProvider
                    .overrideWithValue(ConversationDetailSessionCache()),
                voiceMessageStoreProvider
                    .overrideWith(() => _FakeVoiceMessageStore()),
                sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
                homeListStoreProvider.overrideWith(() => homeStore),
                sharedPreferencesProvider.overrideWithValue(prefs),
                realtimeReductionIngressProvider
                    .overrideWithValue(RealtimeReductionIngress()),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                home: ConversationDetailPage(
                  target: dmTarget,
                  registerOpenTarget: false,
                ),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // No presence subtitle when peerId is null (map returns null).
          expect(
            find.byKey(const ValueKey('conversation-dm-presence')),
            findsNothing,
            reason: 'Presence subtitle must NOT render when map has no entry '
                '(INV-DM-MAP-5)',
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore({required this.initialState});

  final HomeListState initialState;

  @override
  HomeListState build() => initialState;

  /// Emit a state change with a new directMessages list.
  void emitDmChange(List<HomeDirectMessageSummary> dms) {
    state = state.copyWith(directMessages: dms);
  }

  /// Emit a state change that does NOT modify any DM lists.
  void emitNonDmChange() {
    state = state.copyWith(isRefreshing: !state.isRefreshing);
  }
}

class _FakeConversationDetailStore extends ConversationDetailStore {
  _FakeConversationDetailStore({required this.target});

  final ConversationDetailTarget target;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: target,
        status: ConversationDetailStatus.success,
        messages: const [],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> refresh({String reason = 'manual'}) async {}

  @override
  Future<void> loadOlder() async {}

  @override
  Future<void> loadNewer() async {}
}

class _FakeVoiceMessageStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

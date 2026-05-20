import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/stores/notification/notification_foreground_suppression_binding.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// #534: Conversation Notification Settings — Phase B
//
// Verifies per-channel/DM notification preference (mute/unmute).
//
// Storage pattern:
//   SharedPreferences keyed channel_notif_pref_{serverId}_{channelId}
//   with value 'mute' when muted.
//
// Suppression enforcement points:
//   - notification_foreground_suppression_binding.dart (iOS push)
//   - realtime_notification_bridge.dart (WebSocket)
//   Both check channelMutedIdsProvider (in-memory Set<String>).
//
// Invariants:
//   INV-MUTE-1: Conversation info page has notification toggle
//   INV-MUTE-2: Toggle mute persists to local storage
//   INV-MUTE-3: Muted channel suppresses local notifications
//   INV-MUTE-4: Muted channel shows visual indicator in conversation list
//
// Phase B — All invariants active.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-MUTE-1: The conversation info page includes a notification/mute
  // toggle (SwitchListTile with "Mute" or "Notifications" in its title).
  //
  // Setup: Render ConversationDetailPage, tap conversation-members-shortcut
  // to navigate to ConversationInfoPage. The info page must contain a
  // mute/notification SwitchListTile.
  // -----------------------------------------------------------------------
  testWidgets(
    'Conversation info page shows mute toggle (INV-MUTE-1)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = _FakeConversationRepository(
        snapshot: _makeChannelSnapshot(),
      );

      await tester.pumpWidget(_buildConversationApp(repo, prefs));
      await tester.pumpAndSettle();

      // Navigate to info page via the production entry point.
      final membersToggle =
          find.byKey(const ValueKey('conversation-members-shortcut'));
      expect(membersToggle, findsOneWidget,
          reason: 'Members toggle must be in app bar');
      await tester.tap(membersToggle);
      await tester.pumpAndSettle();

      // Info page must be visible.
      expect(
          find.byKey(const ValueKey('conversation-info-page')), findsOneWidget,
          reason: 'Info page must appear after tapping toggle');

      // Mute toggle (SwitchListTile with "Mute" or "Notifications" label)
      // must be present in the info page.
      final muteSwitch = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            (widget.title is Text &&
                ((widget.title! as Text).data?.contains('Mute') == true ||
                    (widget.title! as Text).data?.contains('Notifications') ==
                        true)),
      );
      expect(
        muteSwitch,
        findsOneWidget,
        reason: 'Conversation info page must show a Mute/Notifications '
            'SwitchListTile (INV-MUTE-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MUTE-2: Toggling the mute switch persists the preference to
  // SharedPreferences with key pattern
  // channel_notif_pref_{serverId}_{channelId}.
  //
  // Setup: Initialize SharedPreferences mock. Use
  // ChannelNotificationPreferenceRepository to set mute preference.
  // Read back the stored preference via SharedPreferences API.
  // -----------------------------------------------------------------------
  test(
    'Toggle mute persists to SharedPreferences (INV-MUTE-2)',
    () async {
      // Initialize mock SharedPreferences with empty state.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = ChannelNotificationPreferenceRepository(prefs: prefs);

      const serverId = 'server-1';
      const channelId = 'ch-1';
      final storageKey = ChannelNotificationPreferenceRepository.storageKey(
          serverId, channelId);

      // Before muting: no stored preference.
      expect(prefs.getString(storageKey), isNull,
          reason: 'No preference should be stored initially');
      expect(repo.isChannelMuted(serverId, channelId), isFalse,
          reason: 'Channel should not be muted initially');

      // Mute the channel via the repository.
      await repo.setChannelMuted(serverId, channelId, muted: true);

      // Read back: preference must be persisted.
      final stored = prefs.getString(storageKey);
      expect(stored, equals('mute'),
          reason: 'Mute preference must be persisted to SharedPreferences '
              'with key pattern channel_notif_pref_{serverId}_{channelId} '
              '(INV-MUTE-2)');
      expect(repo.isChannelMuted(serverId, channelId), isTrue,
          reason: 'Repository must report channel as muted');

      // Roundtrip: parse stored value back to enum using existing pattern.
      final parsed = NotificationPreference.fromStorageValue(stored);
      expect(parsed, equals(NotificationPreference.mute),
          reason: 'Stored value must roundtrip to NotificationPreference.mute');

      // Composite key + hydration: getAllMutedCompositeKeys must return the
      // muted channel's composite key for hydrating channelMutedIdsProvider.
      final compositeKey = ChannelNotificationPreferenceRepository.compositeKey(
        serverId,
        channelId,
      );
      expect(compositeKey, equals('server-1_ch-1'),
          reason: 'Composite key must be {serverId}_{channelId}');
      expect(repo.getAllMutedCompositeKeys(), contains(compositeKey),
          reason: 'getAllMutedCompositeKeys must include the muted channel');

      // Unmute the channel.
      await repo.setChannelMuted(serverId, channelId, muted: false);
      expect(prefs.getString(storageKey), isNull,
          reason: 'Unmuting must remove the storage key');
      expect(repo.isChannelMuted(serverId, channelId), isFalse,
          reason: 'Channel must report unmuted after clearing');
      expect(repo.getAllMutedCompositeKeys(), isEmpty,
          reason: 'Hydration set must be empty after unmuting all channels');
    },
  );

  // -----------------------------------------------------------------------
  // INV-MUTE-3: When a channel is muted, local notifications for that
  // channel are suppressed by the foreground suppression binding.
  //
  // The suppression binding checks channelMutedIdsProvider (in-memory
  // Set<String>) for the channelId from the notification payload.
  //
  // Setup: Create ProviderContainer with _FakeNotificationInitializer
  // and channelMutedIdsProvider seeded with 'ch-1'. Push a notification
  // payload with channelId='ch-1'. Assert showLocalNotification is NOT
  // called.
  // -----------------------------------------------------------------------
  test(
    'Muted channel suppresses local notifications (INV-MUTE-3)',
    () async {
      final fakeInitializer = _FakeNotificationInitializer();

      final container = ProviderContainer(
        overrides: [
          notificationInitializerProvider.overrideWithValue(fakeInitializer),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          // Seed the in-memory muted IDs with composite key 'server-1_ch-1'.
          channelMutedIdsProvider.overrideWith(
            (ref) => {
              ChannelNotificationPreferenceRepository.compositeKey(
                'server-1',
                'ch-1',
              ),
            },
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await fakeInitializer.foregroundController.close();
      });

      // Activate the suppression binding (same as production).
      container.read(notificationForegroundSuppressionBindingProvider);

      // Simulate incoming notification for muted channel 'ch-1'.
      fakeInitializer.foregroundController.add({
        'type': 'channel',
        'serverId': 'server-1',
        'channelId': 'ch-1',
        'title': 'New message in #general',
        'body': 'Hello world',
        'senderId': 'other-user',
      });
      await Future<void>.delayed(Duration.zero);

      // Per-channel mute must suppress the notification.
      expect(
        fakeInitializer.displayedPayloads,
        isEmpty,
        reason: 'Notification for muted channel must be suppressed '
            '(INV-MUTE-3)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-MUTE-4: The conversation list shows a visual indicator (mute
  // icon) for muted channels.
  //
  // Setup: Render a HomeChannelRow with isMuted=true. The row must
  // contain a notifications_off icon.
  // -----------------------------------------------------------------------
  testWidgets(
    'Muted channel shows mute indicator in HomeChannelRow (INV-MUTE-4)',
    (tester) async {
      const channel = HomeChannelSummary(
        scopeId: ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
        name: 'general',
        isPrivate: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HomeChannelRow(
                key: ValueKey('channels-tab-${channel.scopeId.value}'),
                channel: channel,
                onTap: () {},
                isMuted: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mute indicator icon must be present within the channel row.
      final channelRow =
          find.byKey(ValueKey('channels-tab-${channel.scopeId.value}'));
      expect(channelRow, findsOneWidget,
          reason: 'Channel row must be rendered');

      final muteIcon = find.descendant(
        of: channelRow,
        matching: find.byIcon(Icons.notifications_off),
      );
      expect(
        muteIcon,
        findsOneWidget,
        reason: 'Muted channel row must show notifications_off icon '
            '(INV-MUTE-4)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConversationDetailSnapshot _makeChannelSnapshot() {
  return ConversationDetailSnapshot(
    target: ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'ch-1',
      ),
    ),
    title: '#general',
    messages: [
      ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello world',
        createdAt: DateTime.parse('2026-05-16T14:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );
}

Widget _buildConversationApp(
  _FakeConversationRepository repo,
  SharedPreferences prefs,
) {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'ch-1',
    ),
  );

  return ProviderScope(
    overrides: [
      appLocalizationsProvider.overrideWithValue(
        lookupAppLocalizations(const Locale('en')),
      ),
      conversationRepositoryProvider.overrideWithValue(repo),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      home: ConversationDetailPage(target: target),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
    );
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'attachment-1';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    return ConversationMessageSummary(
      id: 'sent-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 999,
    );
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
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

// ---------------------------------------------------------------------------
// Notification fakes (same pattern as
// notification_foreground_suppression_binding_test.dart)
// ---------------------------------------------------------------------------

class _FakeNotificationInitializer implements NotificationInitializer {
  final StreamController<Map<String, dynamic>> foregroundController =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> displayedPayloads = [];

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus.unknown;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Map<String, dynamic>?> getInitialNotification() async => null;

  @override
  Stream<Map<String, dynamic>> get onNotificationTapped => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Stream<String> get onTokenChanged => const Stream.empty();

  @override
  Future<void> showLocalNotification(Map<String, dynamic> payload) async {
    displayedPayloads.add(payload);
  }
}

class _FakeSecureStorage implements SecureStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}
}

// ignore_for_file: prefer_const_constructors

// =============================================================================
// #673 — ==/hashCode batch B + silent catch telemetry
//
// Fix 1 Invariant: INV-EQ-673-TRANSLATION
//   TranslationCacheState has value equality on both maps.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 2 Invariant: INV-EQ-673-OUTBOX
//   OutboxState has value equality on items map.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 3 Invariant: INV-EQ-673-LIST-TYPING
//   ListTypingIndicatorState has value equality on displayText.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 4 Invariant: INV-TELEMETRY-673-BACKFILL
//   preview_backfill_service catches log to diagnostics.
//
// Fix 5 Invariant: INV-TELEMETRY-673-NOTIFICATION
//   notification_settings_page catch logs to diagnostics.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/preview_backfill_service.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/realtime/application/list_typing_indicator_store.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

import '../support/support.dart';

// ---------------------------------------------------------------------------
// Throwing fakes for telemetry tests
// ---------------------------------------------------------------------------

/// A ConversationLocalStore that throws on listConversationSummaries.
class _ThrowingConversationLocalStore extends FakeConversationLocalStore {
  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async {
    throw Exception('SQLite unavailable');
  }
}

/// A NotificationStore that throws on requestPermission.
class _ThrowingNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> requestPermission() async {
    throw Exception('Firebase not initialized');
  }

  @override
  Future<void> refreshToken({String? platform}) async {}

  @override
  Future<void> setNotificationPreference(
    NotificationPreference preference,
  ) async {}
}

/// Stub HomeListStore that does nothing — prevents real build() from
/// scheduling load() microtask that accesses un-overridden providers.
class _StubHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState();
}

// ---------------------------------------------------------------------------
// Controllable stores
// ---------------------------------------------------------------------------

class _ControllableTranslationStore extends TranslationCacheStore {
  @override
  TranslationCacheState build() => const TranslationCacheState();

  void setStateDirect(TranslationCacheState s) => state = s;
}

class _ControllableOutboxStore extends OutboxStore {
  @override
  OutboxState build() => const OutboxState();

  void setStateDirect(OutboxState s) => state = s;
}

class _ControllableListTypingStore extends ListTypingIndicatorNotifier {
  @override
  ListTypingIndicatorState build(String arg) {
    ref.onDispose(() {});
    return const ListTypingIndicatorState();
  }

  void setStateDirect(ListTypingIndicatorState s) => state = s;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: TranslationCacheState equality
  // ---------------------------------------------------------------------------
  group('Fix 1: TranslationCacheState ==/hashCode', () {
    test(
        'INV-EQ-673-TRANSLATION: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          translationCacheStoreProvider
              .overrideWith(() => _ControllableTranslationStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        translationCacheStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(translationCacheStoreProvider.notifier)
          as _ControllableTranslationStore;

      // Set initial state.
      store.setStateDirect(TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'Hola',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      ));
      expect(notifyCount, 1);

      // Set identical state (new objects, same content).
      store.setStateDirect(TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'Hola',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      ));

      expect(notifyCount, 1,
          reason: 'identical TranslationCacheState must not notify');
    });

    test('INV-EQ-673-TRANSLATION: changed content DOES trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          translationCacheStoreProvider
              .overrideWith(() => _ControllableTranslationStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        translationCacheStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(translationCacheStoreProvider.notifier)
          as _ControllableTranslationStore;

      store.setStateDirect(TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            status: TranslationEntryStatus.pending,
          ),
        },
      ));
      expect(notifyCount, 1);

      // Change status → content differs.
      store.setStateDirect(TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'Hola',
            status: TranslationEntryStatus.translated,
          ),
        },
      ));
      expect(notifyCount, 2,
          reason: 'changed TranslationCacheState must notify');
    });

    test('INV-EQ-673-TRANSLATION: hashCode is consistent with ==', () {
      final a = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'Hi',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      );
      final b = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'Hi',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 2: OutboxState equality
  // ---------------------------------------------------------------------------
  group('Fix 2: OutboxState ==/hashCode', () {
    test('INV-EQ-673-OUTBOX: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          outboxStoreProvider.overrideWith(() => _ControllableOutboxStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        outboxStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(outboxStoreProvider.notifier)
          as _ControllableOutboxStore;

      final msg = OutboxMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: DateTime(2026, 5, 21),
      );

      store.setStateDirect(OutboxState(items: {
        'ch-1': [msg]
      }));
      expect(notifyCount, 1);

      // Set identical state (new map, same content).
      store.setStateDirect(OutboxState(items: {
        'ch-1': [msg]
      }));

      expect(notifyCount, 1, reason: 'identical OutboxState must not notify');
    });

    test('INV-EQ-673-OUTBOX: changed content DOES trigger notification', () {
      final container = ProviderContainer(
        overrides: [
          outboxStoreProvider.overrideWith(() => _ControllableOutboxStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        outboxStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(outboxStoreProvider.notifier)
          as _ControllableOutboxStore;

      final msg = OutboxMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: DateTime(2026, 5, 21),
      );

      store.setStateDirect(OutboxState(items: {
        'ch-1': [msg]
      }));
      expect(notifyCount, 1);

      // Add another message — content changes.
      final msg2 = OutboxMessage(
        localId: 'local-2',
        content: 'World',
        createdAt: DateTime(2026, 5, 21),
      );
      store.setStateDirect(OutboxState(items: {
        'ch-1': [msg, msg2]
      }));
      expect(notifyCount, 2, reason: 'changed OutboxState must notify');
    });

    test('INV-EQ-673-OUTBOX: hashCode is consistent with ==', () {
      final msg = OutboxMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: DateTime(2026, 5, 21),
      );

      final a = OutboxState(items: {
        'ch-1': [msg]
      });
      final b = OutboxState(items: {
        'ch-1': [msg]
      });

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test(
        'INV-EQ-673-OUTBOX: status change (pending → failed) DOES trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          outboxStoreProvider.overrideWith(() => _ControllableOutboxStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        outboxStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(outboxStoreProvider.notifier)
          as _ControllableOutboxStore;

      final msg = OutboxMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: DateTime(2026, 5, 21),
        status: OutboxMessageStatus.pending,
      );

      store.setStateDirect(OutboxState(items: {
        'ch-1': [msg]
      }));
      expect(notifyCount, 1);

      // Same localId, different status → must notify.
      final msgFailed = OutboxMessage(
        localId: 'local-1',
        content: 'Hello',
        createdAt: DateTime(2026, 5, 21),
        status: OutboxMessageStatus.failed,
        failureMessage: 'Server rejected',
      );
      store.setStateDirect(OutboxState(items: {
        'ch-1': [msgFailed]
      }));
      expect(notifyCount, 2,
          reason: 'status change (pending → failed) must notify');
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 3: ListTypingIndicatorState equality
  // ---------------------------------------------------------------------------
  group('Fix 3: ListTypingIndicatorState ==/hashCode', () {
    test(
        'INV-EQ-673-LIST-TYPING: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          listTypingIndicatorStoreProvider
              .overrideWith(() => _ControllableListTypingStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        listTypingIndicatorStoreProvider('scope-1'),
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier)
              as _ControllableListTypingStore;

      // Set initial state.
      store.setStateDirect(
          ListTypingIndicatorState(displayText: 'Alice is typing...'));
      expect(notifyCount, 1);

      // Set identical state (same displayText, new object).
      store.setStateDirect(
          ListTypingIndicatorState(displayText: 'Alice is typing...'));

      expect(notifyCount, 1,
          reason: 'identical ListTypingIndicatorState must not notify');
    });

    test('INV-EQ-673-LIST-TYPING: changed content DOES trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          listTypingIndicatorStoreProvider
              .overrideWith(() => _ControllableListTypingStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        listTypingIndicatorStoreProvider('scope-1'),
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier)
              as _ControllableListTypingStore;

      store.setStateDirect(
          ListTypingIndicatorState(displayText: 'Alice is typing...'));
      expect(notifyCount, 1);

      // Change displayText.
      store.setStateDirect(
          ListTypingIndicatorState(displayText: 'Alice and Bob are typing...'));
      expect(notifyCount, 2,
          reason: 'changed ListTypingIndicatorState must notify');
    });

    test('INV-EQ-673-LIST-TYPING: null to text triggers notification', () {
      final container = ProviderContainer(
        overrides: [
          listTypingIndicatorStoreProvider
              .overrideWith(() => _ControllableListTypingStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        listTypingIndicatorStoreProvider('scope-1'),
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store =
          container.read(listTypingIndicatorStoreProvider('scope-1').notifier)
              as _ControllableListTypingStore;

      // Start with null (nobody typing) — initial state already null so
      // set to non-null first.
      store.setStateDirect(
          ListTypingIndicatorState(displayText: 'Alice is typing...'));
      expect(notifyCount, 1);

      // Back to null.
      store.setStateDirect(ListTypingIndicatorState(displayText: null));
      expect(notifyCount, 2, reason: 'text → null must notify');
    });

    test('INV-EQ-673-LIST-TYPING: hashCode is consistent with ==', () {
      final a = ListTypingIndicatorState(displayText: 'Alice is typing...');
      final b = ListTypingIndicatorState(displayText: 'Alice is typing...');

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 4: PreviewBackfillService telemetry
  // ---------------------------------------------------------------------------
  group('Fix 4: PreviewBackfillService catch → diagnostics', () {
    const serverId = ServerScopeId('server-1');

    HomeChannelSummary makeChannel(String id) {
      return HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: id),
        name: '#$id',
      );
    }

    test('INV-TELEMETRY-673-BACKFILL: cache exception logs to diagnostics',
        () async {
      final diagnostics = DiagnosticsCollector();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          conversationLocalStoreProvider
              .overrideWithValue(_ThrowingConversationLocalStore()),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          previewMessageFetcherProvider
              .overrideWithValue((_, __) async => null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(previewBackfillServiceProvider.notifier);

      // Call backfill with a channel that needs preview.
      await service.backfill([makeChannel('ch-1')]);

      // Verify diagnostics captured the cache lookup failure.
      final errors = diagnostics.entries
          .where((e) => e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.first.tag, 'PreviewBackfill');
      expect(
        errors.first.message,
        contains('Channel cache lookup failed'),
      );
      expect(errors.first.metadata, containsPair('stackTrace', isNotEmpty));
    });

    test('INV-TELEMETRY-673-BACKFILL: fetch exception logs to diagnostics',
        () async {
      final diagnostics = DiagnosticsCollector();
      final localStore = FakeConversationLocalStore();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          conversationLocalStoreProvider.overrideWithValue(localStore),
          diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          previewMessageFetcherProvider.overrideWithValue(
            (_, __) async => throw Exception('Network timeout'),
          ),
          homeListStoreProvider.overrideWith(() => _StubHomeListStore()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(previewBackfillServiceProvider.notifier);

      // Channel has no cache → Phase 2 will call fetcher which throws.
      await service.backfill([makeChannel('ch-1')]);

      // Verify diagnostics captured the fetch failure.
      final errors = diagnostics.entries
          .where((e) => e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.first.tag, 'PreviewBackfill');
      expect(
        errors.first.message,
        contains('Channel fetch failed for ch-1'),
      );
      expect(errors.first.metadata, containsPair('stackTrace', isNotEmpty));
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 5: NotificationSettingsPage telemetry
  // ---------------------------------------------------------------------------
  group('Fix 5: NotificationSettingsPage catch → diagnostics', () {
    testWidgets(
        'INV-TELEMETRY-673-NOTIFICATION: permission error logs to diagnostics and appears in UI',
        (tester) async {
      final diagnostics = DiagnosticsCollector();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationStoreProvider
                .overrideWith(() => _ThrowingNotificationStore()),
            diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the permission action tile to trigger _updatePermission().
      await tester.tap(
        find.byKey(const ValueKey('notification-settings-permission-action')),
      );
      await tester.pumpAndSettle();

      // Verify diagnostics captured the permission update failure.
      final errors = diagnostics.entries
          .where((e) => e.level == DiagnosticsLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.first.tag, 'notification');
      expect(
        errors.first.message,
        contains('Permission update failed'),
      );
      expect(errors.first.metadata, containsPair('stackTrace', isNotEmpty));

      // Verify the error appears in the diagnostics panel UI (tag == 'notification').
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notification-diagnostics-events')),
        200,
      );
      expect(
        find.textContaining('Permission update failed'),
        findsOneWidget,
        reason: 'telemetry error must surface in diagnostics UI panel',
      );
    });
  });
}

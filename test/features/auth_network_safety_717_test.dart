// =============================================================================
// #717 — Auth + Network Safety
//
// A. P1: Token refresh race — concurrent 401 causes spurious logout
// B. P2: OutboxStore.drainAll suppresses second connectivity event
// C. P2: RealtimeReductionIngress.accept() throws StateError after dispose
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  group('#717A — P1: Token refresh race — real refreshAuthTokenProvider', () {
    late ProviderContainer container;
    late _InMemorySecureStorage storage;

    /// Creates a Dio that always responds with 401.
    Dio dioReturning401() {
      final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'));
      dio.httpClientAdapter = _FakeHttpClientAdapter(statusCode: 401);
      return dio;
    }

    test('refresh 401 does NOT logout when refresh token was already rotated',
        () async {
      // Setup: storage starts with token-A. A parallel refresh will rotate
      // it to token-B before the 401 handler checks.
      storage = _InMemorySecureStorage({
        SessionStorageKeys.refreshToken: 'token-A',
      });

      // The Dio adapter simulates 401. But before the response arrives,
      // we need storage to contain token-B. We accomplish this by using a
      // storage wrapper that rotates on the second read of refreshToken.
      final rotatingStorage = _RotatingSecureStorage(
        delegate: storage,
        rotateKey: SessionStorageKeys.refreshToken,
        rotateToValue: 'token-B',
      );

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(rotatingStorage),
          refreshDioProvider.overrideWithValue(dioReturning401()),
        ],
      );
      addTearDown(container.dispose);

      // Execute the real production refreshAuthToken function.
      final refreshFn = container.read(refreshAuthTokenProvider);
      final result = await refreshFn();

      // Should return null (refresh failed).
      expect(result, isNull);

      // Should NOT have called logout — token was already rotated.
      final sessionState = container.read(sessionStoreProvider);
      expect(sessionState.status, isNot(AuthStatus.unauthenticated),
          reason: 'Must NOT logout when refresh token was rotated by '
              'parallel refresh (token-B != token-A)');
    });

    test('refresh 401 DOES logout when refresh token was NOT rotated',
        () async {
      // Setup: storage has token-A, and it stays as token-A throughout.
      storage = _InMemorySecureStorage({
        SessionStorageKeys.refreshToken: 'token-A',
      });

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          refreshDioProvider.overrideWithValue(dioReturning401()),
        ],
      );
      addTearDown(container.dispose);

      final refreshFn = container.read(refreshAuthTokenProvider);
      final result = await refreshFn();

      expect(result, isNull);

      // Token was NOT rotated, so logout SHOULD be called.
      final sessionState = container.read(sessionStoreProvider);
      expect(sessionState.status, AuthStatus.unauthenticated,
          reason: 'Must logout when refresh token was NOT rotated '
              '(same token-A on re-read)');
    });

    test('refresh 401 with empty stored token does NOT logout', () async {
      // Edge case: refresh token is empty/null — should return null early
      // without even hitting the network.
      storage = _InMemorySecureStorage({
        SessionStorageKeys.refreshToken: '',
      });

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          refreshDioProvider.overrideWithValue(dioReturning401()),
        ],
      );
      addTearDown(container.dispose);

      final refreshFn = container.read(refreshAuthTokenProvider);
      final result = await refreshFn();

      expect(result, isNull);
      // Should not reach the Dio call at all.
      final sessionState = container.read(sessionStoreProvider);
      expect(sessionState.status, isNot(AuthStatus.unauthenticated));
    });
  });

  group('#717B — P2: OutboxStore drainAll re-check (real store)', () {
    late ProviderContainer container;
    late _FakeConversationRepository repository;
    late StreamController<ConnectivityStatus> connectivityController;
    late ConnectivityService connectivityService;

    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = _FakeConversationRepository();
      connectivityController = StreamController<ConnectivityStatus>.broadcast();
      connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );

      container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      await connectivityController.close();
    });

    test('failed-only queue does NOT trigger infinite re-drain spin', () async {
      // Pre-populate outbox with a FAILED item via SharedPreferences.
      final prefs = container.read(sharedPreferencesProvider);
      final targetKey = outboxTargetKey(target);
      final queueJson = jsonEncode({
        targetKey: [
          {
            'localId': 'failed-msg-1',
            'content': 'I already failed',
            'status': 'failed',
            'createdAt': '2026-05-07T12:00:00.000Z',
            'failureMessage': 'Forbidden',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      // Rebuild with fresh container to load persisted state.
      // Use offline to prevent auto-drain, then go online manually.
      final offlineController =
          StreamController<ConnectivityStatus>.broadcast();
      final offlineService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: offlineController,
      );
      final freshContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() {
        freshContainer.dispose();
        offlineController.close();
      });

      // Read the store — it should load the failed item.
      final notifier = freshContainer.read(outboxStoreProvider.notifier);
      final stateBeforeDrain = freshContainer.read(outboxStoreProvider);
      expect(stateBeforeDrain.items[targetKey], hasLength(1));
      expect(stateBeforeDrain.items[targetKey]![0].status,
          OutboxMessageStatus.failed);

      // Call drainAll. Since items are all failed (no pending), the re-check
      // should NOT schedule another drainAll (no infinite spin).
      await notifier.drainAll();

      // Give microtasks a chance to execute (if spin bug existed, it would
      // schedule another drainAll here).
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The repository should NOT have been called — failed items aren't retried.
      expect(repository.sentContents, isEmpty,
          reason: 'Failed items must not be retried by drainAll');

      // State unchanged.
      final stateAfter = freshContainer.read(outboxStoreProvider);
      expect(stateAfter.items[targetKey], hasLength(1));
      expect(
          stateAfter.items[targetKey]![0].status, OutboxMessageStatus.failed);
    });

    test('pending items after drain DO trigger fresh drain via re-check',
        () async {
      // Scenario: drain starts, first item succeeds but during that drain,
      // a new item is enqueued. The re-check after drain finds remaining
      // pending items and schedules a fresh drain via Timer(100ms).
      final notifier = container.read(outboxStoreProvider.notifier);

      // Use a gate to control when the first send completes.
      repository.sendGate = Completer<void>();
      repository.sendStarted = Completer<void>();

      // Enqueue first item.
      notifier.enqueue(target, 'First message', localId: 'msg-1');

      // Start draining.
      final drainFuture = notifier.drainAll();

      // Wait for send to start.
      await repository.sendStarted!.future;

      // While drain is in progress, enqueue another item.
      notifier.enqueue(target, 'Second message', localId: 'msg-2');

      // Complete the first send.
      repository.sendGate!.complete();
      await drainFuture;

      // The reschedule uses Timer(100ms) — wait for it to fire.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await Future<void>.delayed(Duration.zero);

      // Both messages should have been sent.
      expect(repository.sentContents, ['First message', 'Second message'],
          reason:
              'Re-check after drain must pick up items added during the drain');

      // Queue should be empty.
      final stateAfter = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(stateAfter.items[targetKey], isNull,
          reason: 'All items should be drained');
    });

    test(
        'mixed failed + pending: only pending items drained, failed items remain',
        () async {
      // Pre-populate with one failed + one pending item.
      final prefs = container.read(sharedPreferencesProvider);
      final targetKey = outboxTargetKey(target);
      final queueJson = jsonEncode({
        targetKey: [
          {
            'localId': 'failed-msg',
            'content': 'Already failed',
            'status': 'failed',
            'createdAt': '2026-05-07T12:00:00.000Z',
            'failureMessage': 'Forbidden',
          },
          {
            'localId': 'pending-msg',
            'content': 'Still pending',
            'status': 'pending',
            'createdAt': '2026-05-07T12:01:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      // Fresh container with ONLINE connectivity — the startup auto-drain
      // microtask will fire and drain pending items.
      final onlineController = StreamController<ConnectivityStatus>.broadcast();
      final onlineService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: onlineController,
      );
      final freshContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(onlineService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() {
        freshContainer.dispose();
        onlineController.close();
      });

      // Reading the provider triggers build() which schedules auto-drain.
      freshContainer.read(outboxStoreProvider);

      // Let the microtask-scheduled drainAll execute.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Pending item was sent.
      expect(repository.sentContents, ['Still pending']);

      // Failed item remains in queue.
      final stateAfter = freshContainer.read(outboxStoreProvider);
      expect(stateAfter.items[targetKey], hasLength(1));
      expect(stateAfter.items[targetKey]![0].localId, 'failed-msg');
      expect(
          stateAfter.items[targetKey]![0].status, OutboxMessageStatus.failed);
    });
  });

  group('#717C — P2: RealtimeReductionIngress accept() after dispose', () {
    test('accept() returns false after dispose — no StateError', () async {
      final ingress = RealtimeReductionIngress();
      final envelope = RealtimeEventEnvelope(
        eventType: 'message',
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        seq: 1,
      );

      // Before dispose: accept works.
      expect(ingress.accept(envelope), isTrue);

      // Dispose.
      await ingress.dispose();

      // After dispose: accept returns false without throwing.
      final envelope2 = RealtimeEventEnvelope(
        eventType: 'message',
        scopeKey: 'server:s1/channel:ch1',
        receivedAt: DateTime.now(),
        seq: 2,
      );
      expect(ingress.accept(envelope2), isFalse,
          reason: 'accept() must return false after dispose, not throw');
    });

    test('multiple accept() calls after dispose are all safe', () async {
      final ingress = RealtimeReductionIngress();
      await ingress.dispose();

      for (var i = 0; i < 10; i++) {
        final result = ingress.accept(RealtimeEventEnvelope(
          eventType: 'typing',
          scopeKey: 'server:s1/channel:ch$i',
          receivedAt: DateTime.now(),
          seq: i,
        ));
        expect(result, isFalse);
      }
      // No exception = test passes.
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory SecureStorage for tests.
class _InMemorySecureStorage implements SecureStorage {
  _InMemorySecureStorage([Map<String, String>? initial])
      : _store = Map<String, String>.from(initial ?? {});

  final Map<String, String> _store;

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

/// SecureStorage that rotates a specific key's value on the second read.
///
/// This simulates a parallel refresh succeeding and writing a new token
/// between the initial read and the re-read in the 401 handler.
class _RotatingSecureStorage implements SecureStorage {
  _RotatingSecureStorage({
    required this.delegate,
    required this.rotateKey,
    required this.rotateToValue,
  });

  final _InMemorySecureStorage delegate;
  final String rotateKey;
  final String rotateToValue;
  int _readCount = 0;

  @override
  Future<String?> read({required String key}) async {
    if (key == rotateKey) {
      _readCount++;
      if (_readCount == 1) {
        // First read: return original value.
        return delegate.read(key: key);
      }
      // Second+ read: simulate parallel rotation having occurred.
      await delegate.write(key: key, value: rotateToValue);
      return rotateToValue;
    }
    return delegate.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) =>
      delegate.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => delegate.delete(key: key);
}

/// Fake Dio HttpClientAdapter that always returns a response with the given
/// status code, simulating server errors without network access.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.statusCode});

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error": "simulated"}',
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Fake ConversationRepository for outbox tests.
class _FakeConversationRepository implements ConversationRepository {
  ConversationMessageSummary? sentMessage;
  AppFailure? sendFailure;
  Completer<void>? sendGate;
  Completer<void>? sendStarted;
  final List<String> sentContents = [];

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    if (!(sendStarted?.isCompleted ?? true)) {
      sendStarted!.complete();
    }
    if (sendGate != null) {
      await sendGate!.future;
    }
    if (sendFailure != null) throw sendFailure!;
    return sentMessage ??
        ConversationMessageSummary(
          id: 'msg-${sentContents.length}',
          content: content,
          createdAt: DateTime.now(),
          senderType: 'human',
          messageType: 'message',
          seq: sentContents.length,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

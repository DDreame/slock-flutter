// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

// =============================================================================
// #672 — ==/hashCode batch A — rebuild suppression invariants
//
// Fix 1 Invariant: INV-EQ-672-TYPING
//   TypingIndicatorState has value equality based on activeTypers list.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 2 Invariant: INV-EQ-672-ANNOUNCEMENT
//   AnnouncementState has value equality based on status, announcements, failure.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 3 Invariant: INV-EQ-672-PRESENCE
//   PresenceState has value equality based on statuses map.
//   Setting identical content MUST NOT trigger listener notification.
//
// Fix 4 Invariant: INV-EQ-672-VOICE
//   VoiceMessageState has value equality based on all 4 fields.
//   Setting identical content MUST NOT trigger listener notification.
//
// Each test uses a ProviderContainer with a listener counting
// notifications. Identical state = no extra notification.
// Changed state = notification fires.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

// ---------------------------------------------------------------------------
// Controllable stores — expose state setter for direct mutation.
// ---------------------------------------------------------------------------

class _ControllableTypingStore extends TypingIndicatorStore {
  @override
  TypingIndicatorState build() {
    ref.onDispose(() {});
    return const TypingIndicatorState();
  }

  void setStateDirect(TypingIndicatorState s) => state = s;

  @override
  void addTyper({
    required String userId,
    required String displayName,
    Duration expiry = kTypingIndicatorExpiry,
  }) {
    // State-only — no Timer allocation.
    final existing = state.activeTypers;
    final updated = existing.where((t) => t.userId != userId).toList()
      ..add(ActiveTyper(userId: userId, displayName: displayName));
    state = state.copyWith(activeTypers: updated);
  }

  @override
  void removeTyper(String userId) {
    final updated =
        state.activeTypers.where((t) => t.userId != userId).toList();
    if (updated.length != state.activeTypers.length) {
      state = state.copyWith(activeTypers: updated);
    }
  }

  @override
  void clearAll() {
    state = const TypingIndicatorState();
  }
}

class _ControllableAnnouncementStore extends AnnouncementStore {
  @override
  AnnouncementState build() => const AnnouncementState();

  void setStateDirect(AnnouncementState s) => state = s;
}

class _ControllablePresenceStore extends PresenceStore {
  @override
  PresenceState build() => const PresenceState();

  void setStateDirect(PresenceState s) => state = s;
}

class _ControllableVoiceStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();

  void setStateDirect(VoiceMessageState s) => state = s;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: TypingIndicatorState equality
  // ---------------------------------------------------------------------------
  group('Fix 1: TypingIndicatorState ==/hashCode', () {
    test('INV-EQ-672-TYPING: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          typingIndicatorStoreProvider
              .overrideWith(() => _ControllableTypingStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        typingIndicatorStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(typingIndicatorStoreProvider.notifier)
          as _ControllableTypingStore;

      // Set initial state with one typer.
      store.addTyper(userId: 'u1', displayName: 'Alice');
      expect(notifyCount, 1);

      // Set identical state (same typer list content, new object).
      store.setStateDirect(TypingIndicatorState(
        activeTypers: [
          const ActiveTyper(userId: 'u1', displayName: 'Alice'),
        ],
      ));

      // Must NOT notify — equal content.
      expect(notifyCount, 1,
          reason: 'identical TypingIndicatorState must not notify');
    });

    test('INV-EQ-672-TYPING: changed content DOES trigger notification', () {
      final container = ProviderContainer(
        overrides: [
          typingIndicatorStoreProvider
              .overrideWith(() => _ControllableTypingStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        typingIndicatorStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(typingIndicatorStoreProvider.notifier)
          as _ControllableTypingStore;

      store.addTyper(userId: 'u1', displayName: 'Alice');
      expect(notifyCount, 1);

      // Add second typer — content changes.
      store.addTyper(userId: 'u2', displayName: 'Bob');
      expect(notifyCount, 2,
          reason: 'changed TypingIndicatorState must notify');
    });

    test('INV-EQ-672-TYPING: hashCode is consistent with ==', () {
      const a = TypingIndicatorState(activeTypers: [
        ActiveTyper(userId: 'u1', displayName: 'Alice'),
      ]);
      final b = TypingIndicatorState(activeTypers: [
        const ActiveTyper(userId: 'u1', displayName: 'Alice'),
      ]);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 2: AnnouncementState equality
  // ---------------------------------------------------------------------------
  group('Fix 2: AnnouncementState ==/hashCode', () {
    final announcement = Announcement(
      id: 'ann-1',
      title: 'Test',
      body: 'Body',
      createdAt: DateTime(2026, 5, 21),
    );

    test(
        'INV-EQ-672-ANNOUNCEMENT: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          announcementStoreProvider
              .overrideWith(() => _ControllableAnnouncementStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        announcementStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(announcementStoreProvider.notifier)
          as _ControllableAnnouncementStore;

      // Set initial state.
      store.setStateDirect(AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [announcement],
      ));
      expect(notifyCount, 1);

      // Set identical state (new object, same content).
      store.setStateDirect(AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [announcement],
      ));

      // Must NOT notify — equal content.
      expect(notifyCount, 1,
          reason: 'identical AnnouncementState must not notify');
    });

    test('INV-EQ-672-ANNOUNCEMENT: changed content DOES trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          announcementStoreProvider
              .overrideWith(() => _ControllableAnnouncementStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        announcementStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(announcementStoreProvider.notifier)
          as _ControllableAnnouncementStore;

      store.setStateDirect(AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [announcement],
      ));
      expect(notifyCount, 1);

      // Change status — content differs.
      store.setStateDirect(AnnouncementState(
        status: AnnouncementStatus.loading,
        announcements: [announcement],
      ));
      expect(notifyCount, 2, reason: 'changed AnnouncementState must notify');
    });

    test('INV-EQ-672-ANNOUNCEMENT: hashCode is consistent with ==', () {
      final a = AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [announcement],
      );
      final b = AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [announcement],
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 3: PresenceState equality
  // ---------------------------------------------------------------------------
  group('Fix 3: PresenceState ==/hashCode', () {
    test('INV-EQ-672-PRESENCE: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          presenceStoreProvider
              .overrideWith(() => _ControllablePresenceStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        presenceStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(presenceStoreProvider.notifier)
          as _ControllablePresenceStore;

      // Set initial state.
      store.setStateDirect(PresenceState(
        statuses: Map.of(const {'u1': UserPresenceStatus.online}),
      ));
      expect(notifyCount, 1);

      // Set identical state (new map, same content).
      store.setStateDirect(PresenceState(
        statuses: Map.of(const {'u1': UserPresenceStatus.online}),
      ));

      // Must NOT notify — equal content.
      expect(notifyCount, 1, reason: 'identical PresenceState must not notify');
    });

    test('INV-EQ-672-PRESENCE: changed content DOES trigger notification', () {
      final container = ProviderContainer(
        overrides: [
          presenceStoreProvider
              .overrideWith(() => _ControllablePresenceStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        presenceStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(presenceStoreProvider.notifier)
          as _ControllablePresenceStore;

      store.setStateDirect(PresenceState(
        statuses: Map.of(const {'u1': UserPresenceStatus.online}),
      ));
      expect(notifyCount, 1);

      // Add a user — content changes.
      store.setStateDirect(PresenceState(
        statuses: Map.of(const {
          'u1': UserPresenceStatus.online,
          'u2': UserPresenceStatus.idle,
        }),
      ));
      expect(notifyCount, 2, reason: 'changed PresenceState must notify');
    });

    test('INV-EQ-672-PRESENCE: hashCode is consistent with ==', () {
      const a = PresenceState(
        statuses: {
          'u1': UserPresenceStatus.online,
          'u2': UserPresenceStatus.idle
        },
      );
      const b = PresenceState(
        statuses: {
          'u1': UserPresenceStatus.online,
          'u2': UserPresenceStatus.idle
        },
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('INV-EQ-672-PRESENCE: hashCode is order-independent', () {
      const a = PresenceState(
        statuses: {
          'u1': UserPresenceStatus.online,
          'u2': UserPresenceStatus.idle
        },
      );
      const b = PresenceState(
        statuses: {
          'u2': UserPresenceStatus.idle,
          'u1': UserPresenceStatus.online
        },
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  // Fix 4: VoiceMessageState equality
  // ---------------------------------------------------------------------------
  group('Fix 4: VoiceMessageState ==/hashCode', () {
    test('INV-EQ-672-VOICE: identical content does NOT trigger notification',
        () {
      final container = ProviderContainer(
        overrides: [
          voiceMessageStoreProvider
              .overrideWith(() => _ControllableVoiceStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        voiceMessageStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(voiceMessageStoreProvider.notifier)
          as _ControllableVoiceStore;

      // Set initial state.
      store.setStateDirect(VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: const Duration(seconds: 5),
        amplitudes: List.of(const [0.1, 0.5, 0.8]),
        recordedFilePath: '/path/to/file.m4a',
      ));
      expect(notifyCount, 1);

      // Set identical state (new object, same content).
      store.setStateDirect(VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: const Duration(seconds: 5),
        amplitudes: List.of(const [0.1, 0.5, 0.8]),
        recordedFilePath: '/path/to/file.m4a',
      ));

      // Must NOT notify — equal content.
      expect(notifyCount, 1,
          reason: 'identical VoiceMessageState must not notify');
    });

    test('INV-EQ-672-VOICE: changed content DOES trigger notification', () {
      final container = ProviderContainer(
        overrides: [
          voiceMessageStoreProvider
              .overrideWith(() => _ControllableVoiceStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        voiceMessageStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(voiceMessageStoreProvider.notifier)
          as _ControllableVoiceStore;

      store.setStateDirect(VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: const Duration(seconds: 5),
        amplitudes: List.of(const [0.1, 0.5, 0.8]),
      ));
      expect(notifyCount, 1);

      // Change elapsed — content differs.
      store.setStateDirect(VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: const Duration(seconds: 6),
        amplitudes: List.of(const [0.1, 0.5, 0.8]),
      ));
      expect(notifyCount, 2, reason: 'changed VoiceMessageState must notify');
    });

    test('INV-EQ-672-VOICE: amplitude change triggers notification', () {
      final container = ProviderContainer(
        overrides: [
          voiceMessageStoreProvider
              .overrideWith(() => _ControllableVoiceStore()),
        ],
      );
      addTearDown(container.dispose);

      int notifyCount = 0;
      container.listen(
        voiceMessageStoreProvider,
        (_, __) => notifyCount++,
        fireImmediately: false,
      );

      final store = container.read(voiceMessageStoreProvider.notifier)
          as _ControllableVoiceStore;

      store.setStateDirect(VoiceMessageState(
        amplitudes: List.of(const [0.1, 0.5]),
      ));
      expect(notifyCount, 1);

      // Append amplitude — content differs.
      store.setStateDirect(VoiceMessageState(
        amplitudes: List.of(const [0.1, 0.5, 0.9]),
      ));
      expect(notifyCount, 2, reason: 'changed amplitudes must notify');
    });

    test('INV-EQ-672-VOICE: hashCode is consistent with ==', () {
      const a = VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: Duration(seconds: 5),
        amplitudes: [0.1, 0.5, 0.8],
        recordedFilePath: '/path/to/file.m4a',
      );
      const b = VoiceMessageState(
        recordingState: VoiceRecorderState.recording,
        elapsed: Duration(seconds: 5),
        amplitudes: [0.1, 0.5, 0.8],
        recordedFilePath: '/path/to/file.m4a',
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });
  });
}

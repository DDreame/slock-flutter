import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/settings/application/toggle_channel_mute_use_case.dart';
import 'package:slock_app/features/settings/data/channel_notification_preference.dart';

// ---------------------------------------------------------------------------
// Fake repository that records calls without needing SharedPreferences.
// ---------------------------------------------------------------------------

class _RecordingRepository implements ChannelNotificationPreferenceRepository {
  final List<({String serverId, String channelId, bool muted})> calls = [];
  bool shouldThrow = false;

  @override
  bool isChannelMuted(String serverId, String channelId) => false;

  @override
  Set<String> getAllMutedCompositeKeys() => const {};

  @override
  Future<void> setChannelMuted(
    String serverId,
    String channelId, {
    required bool muted,
  }) async {
    if (shouldThrow) {
      throw Exception('persistence failure');
    }
    calls.add((serverId: serverId, channelId: channelId, muted: muted));
  }
}

void main() {
  const serverId = 'server-1';
  const channelId = 'ch-general';

  late _RecordingRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _RecordingRepository();
    container = ProviderContainer(
      overrides: [
        channelNotificationPreferenceRepositoryProvider.overrideWithValue(repo),
        channelMutedIdsProvider.overrideWith((ref) => <String>{}),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('toggleChannelMuteUseCaseProvider', () {
    test('mute=true persists and adds to in-memory set', () async {
      final toggle = container.read(toggleChannelMuteUseCaseProvider);

      await toggle(
        serverId: serverId,
        channelId: channelId,
        muted: true,
      );

      // Verify persistence call.
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.serverId, serverId);
      expect(repo.calls.single.channelId, channelId);
      expect(repo.calls.single.muted, true);

      // Verify in-memory set updated.
      final mutedIds = container.read(channelMutedIdsProvider);
      final expectedKey = ChannelNotificationPreferenceRepository.compositeKey(
          serverId, channelId);
      expect(mutedIds, contains(expectedKey));
    });

    test('mute=false persists and removes from in-memory set', () async {
      // Pre-populate the muted IDs set.
      final key = ChannelNotificationPreferenceRepository.compositeKey(
          serverId, channelId);
      container.read(channelMutedIdsProvider.notifier).state = {key};

      final toggle = container.read(toggleChannelMuteUseCaseProvider);

      await toggle(
        serverId: serverId,
        channelId: channelId,
        muted: false,
      );

      // Verify persistence call.
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.muted, false);

      // Verify in-memory set no longer contains the key.
      final mutedIds = container.read(channelMutedIdsProvider);
      expect(mutedIds, isNot(contains(key)));
    });

    test('error from repository propagates to caller', () async {
      repo.shouldThrow = true;
      final toggle = container.read(toggleChannelMuteUseCaseProvider);

      expect(
        () => toggle(serverId: serverId, channelId: channelId, muted: true),
        throwsA(isA<Exception>()),
      );
    });

    test('multiple channels can be muted independently', () async {
      final toggle = container.read(toggleChannelMuteUseCaseProvider);

      await toggle(serverId: serverId, channelId: 'ch-a', muted: true);
      await toggle(serverId: serverId, channelId: 'ch-b', muted: true);

      final mutedIds = container.read(channelMutedIdsProvider);
      expect(mutedIds, hasLength(2));
      expect(
        mutedIds,
        containsAll([
          ChannelNotificationPreferenceRepository.compositeKey(
              serverId, 'ch-a'),
          ChannelNotificationPreferenceRepository.compositeKey(
              serverId, 'ch-b'),
        ]),
      );
    });
  });
}

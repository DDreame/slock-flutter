// =============================================================================
// #844 — P1 Bounds Guards (3 indexWhere) + P2 Disposed Guards (2 stores)
//
// Load-bearing tests:
// 1. WorkspacesStore.deleteWorkspace with nonexistent ID → no throw, state unchanged
// 2. ChannelMemberStore.removeHumanMember with nonexistent userId → no throw
// 3. ChannelMemberStore.removeAgentMember with nonexistent agentId → no throw
// 4. TranslationCacheStore.translateMessage after dispose → state unchanged
// 5. ProfileEditStore.pickAvatar after dispose → state unchanged
//
// Falsification: removing the `if (removedIndex < 0) return;` or `_disposed`
// guards must make these tests RED (RangeError / StateError / state mutation).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/application/profile_edit_store.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // Group 1: Bounds guards — indexWhere returning -1 must not crash
  // ===========================================================================
  group('#844 — Bounds guards', () {
    test('WorkspacesStore.deleteWorkspace with nonexistent ID returns silently',
        () async {
      final container = ProviderContainer(overrides: [
        currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
        machinesRepositoryProvider.overrideWithValue(_NoOpMachinesRepo()),
      ]);

      final sub = container.listen(workspacesStoreProvider, (_, __) {});
      final store = container.read(workspacesStoreProvider.notifier);

      // Seed with one workspace.
      store.state = WorkspacesState(
        status: WorkspacesStatus.success,
        items: [
          WorkspaceItem(
            id: 'ws-1',
            name: 'Test Workspace',
            machineId: 'machine-1',
            createdAt: DateTime(2024),
          ),
        ],
      );

      // Delete nonexistent ID — must not throw RangeError.
      await store.deleteWorkspace('nonexistent-id');

      // State unchanged.
      expect(store.state.items.length, 1);
      expect(store.state.items.first.id, 'ws-1');

      sub.close();
      container.dispose();
    });

    test(
        'ChannelMemberStore.removeHumanMember with nonexistent userId returns silently',
        () async {
      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider
            .overrideWithValue(const ServerScopeId('srv-1')),
        currentChannelMemberChannelIdProvider.overrideWithValue('ch-1'),
        channelMemberRepositoryProvider
            .overrideWithValue(_NoOpChannelMemberRepo()),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);

      // Seed with one member.
      store.state = const ChannelMemberState(
        status: ChannelMemberStatus.success,
        items: [
          ChannelMember(
              id: 'm1', channelId: 'ch-1', userId: 'u1', userName: 'Alice'),
        ],
      );

      // Remove nonexistent userId — must not throw RangeError.
      await store.removeHumanMember('nonexistent-user');

      // State unchanged.
      expect(store.state.items.length, 1);
      expect(store.state.items.first.userId, 'u1');

      sub.close();
      container.dispose();
    });

    test(
        'ChannelMemberStore.removeAgentMember with nonexistent agentId returns silently',
        () async {
      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider
            .overrideWithValue(const ServerScopeId('srv-1')),
        currentChannelMemberChannelIdProvider.overrideWithValue('ch-1'),
        channelMemberRepositoryProvider
            .overrideWithValue(_NoOpChannelMemberRepo()),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);

      // Seed with one member.
      store.state = const ChannelMemberState(
        status: ChannelMemberStatus.success,
        items: [
          ChannelMember(
              id: 'm1', channelId: 'ch-1', agentId: 'a1', userName: 'Bot-1'),
        ],
      );

      // Remove nonexistent agentId — must not throw RangeError.
      await store.removeAgentMember('nonexistent-agent');

      // State unchanged.
      expect(store.state.items.length, 1);
      expect(store.state.items.first.agentId, 'a1');

      sub.close();
      container.dispose();
    });
  });

  // ===========================================================================
  // Group 2: Disposed guards — state must not mutate after disposal
  // ===========================================================================
  group('#844 — Disposed guards', () {
    test(
        'TranslationCacheStore.translateMessage after dispose does not mutate state',
        () async {
      final completer = Completer<List<TranslationResult>>();
      final repo = _DelayedTranslationRepo(completer);

      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('srv-1')),
        translationRepositoryProvider.overrideWithValue(repo),
        translationSettingsStoreProvider
            .overrideWith(() => _PreloadedSettingsStore()),
      ]);

      final sub = container.listen(translationCacheStoreProvider, (_, __) {});
      final store = container.read(translationCacheStoreProvider.notifier);

      // Start translateMessage — will await the delayed repo.
      final future = store.translateMessage('msg-1');

      // Dispose before the translation resolves.
      sub.close();
      container.dispose();

      // Resolve after disposal with a successful translation.
      completer.complete([
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'Translated text',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
          status: TranslationStatus.translated,
        ),
      ]);
      await future;

      // The translateMessage method has a `if (_disposed) return;` guard after
      // _translateMessages — without it, the subsequent `state = ...` setting
      // showTranslation would mutate state post-dispose.
      expect(store.state.showTranslation.containsKey('msg-1'), isFalse,
          reason:
              'translateMessage must not mutate state after store is disposed');
    });

    test('ProfileEditStore.pickAvatar after dispose does not mutate state',
        () async {
      final pickCompleter = Completer<String?>();
      final picker = _DelayedImagePicker(pickCompleter);

      final container = ProviderContainer(overrides: [
        imagePickerProvider.overrideWithValue(picker),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);

      final initialState = store.state;

      // Start pickAvatar — will await the delayed picker.
      final future = store.pickAvatar();

      // Dispose before the picker resolves.
      sub.close();
      container.dispose();

      // Resolve with a path after disposal.
      pickCompleter.complete('/some/path.png');
      await future;

      // State must remain unchanged — the `|| _disposed` guard in pickAvatar
      // prevents setSelectedAvatarPath from being called post-dispose.
      expect(store.state.selectedAvatarPath, initialState.selectedAvatarPath,
          reason: 'pickAvatar must not mutate state after store is disposed');
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _NoOpMachinesRepo implements MachinesRepository {
  @override
  Future<void> deleteWorkspace(String machineId,
          {required String workspaceId}) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpChannelMemberRepo implements ChannelMemberRepository {
  @override
  Future<void> removeHumanMember(ServerScopeId serverId,
          {required String channelId, required String userId}) async =>
      {};

  @override
  Future<void> removeAgentMember(ServerScopeId serverId,
          {required String channelId, required String agentId}) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Returns results only when the completer fires — simulates a slow API call.
class _DelayedTranslationRepo implements TranslationRepository {
  _DelayedTranslationRepo(this._completer);

  final Completer<List<TranslationResult>> _completer;

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) =>
      _completer.future;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async =>
      const TranslationSettings();

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) async =>
      settings;
}

/// Provides a pre-loaded TranslationSettingsState with preferredLanguage 'zh'.
class _PreloadedSettingsStore extends TranslationSettingsStore {
  @override
  TranslationSettingsState build() {
    return const TranslationSettingsState(
      status: TranslationSettingsStatus.success,
      settings: TranslationSettings(
        preferredLanguage: 'zh',
        mode: TranslationMode.manual,
      ),
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> update(TranslationSettings settings) async {
    state = state.copyWith(settings: settings);
  }
}

/// Minimal SessionStore that returns an empty session.
class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState();
}

/// Image picker that delays until the completer fires.
class _DelayedImagePicker implements ImagePickerService {
  _DelayedImagePicker(this._completer);

  final Completer<String?> _completer;

  @override
  Future<String?> pickImage() => _completer.future;
}

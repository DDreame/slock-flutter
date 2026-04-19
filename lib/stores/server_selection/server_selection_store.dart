import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';

final serverSelectionStoreProvider =
    NotifierProvider<ServerSelectionStore, ServerSelectionState>(
  ServerSelectionStore.new,
);

class ServerSelectionStore extends Notifier<ServerSelectionState> {
  @override
  ServerSelectionState build() => const ServerSelectionState();

  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> selectServer(String serverId) async {
    state = state.copyWith(selectedServerId: serverId);
    await _storage.write(
      key: ServerSelectionStorageKeys.selectedServerId,
      value: serverId,
    );
  }

  Future<void> restoreSelection() async {
    try {
      final serverId = await _storage.read(
        key: ServerSelectionStorageKeys.selectedServerId,
      );
      if (serverId != null) {
        state = state.copyWith(selectedServerId: serverId);
      } else {
        state = state.copyWith(clearSelectedServerId: true);
      }
    } catch (_) {
      state = state.copyWith(clearSelectedServerId: true);
    }
  }

  Future<void> clearSelection() async {
    state = state.copyWith(clearSelectedServerId: true);
    await ServerSelectionStorageKeys.clear(_storage);
  }
}

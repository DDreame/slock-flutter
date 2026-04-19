import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};
  bool shouldThrow = false;

  @override
  Future<String?> read({required String key}) async {
    if (shouldThrow) throw Exception('storage read failure');
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  Map<String, String> get snapshot => Map.unmodifiable(_store);
}

void main() {
  late ProviderContainer container;
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  ServerSelectionStore readStore() =>
      container.read(serverSelectionStoreProvider.notifier);

  ServerSelectionState readState() =>
      container.read(serverSelectionStoreProvider);

  group('ServerSelectionStore', () {
    test('initial state has null selectedServerId', () {
      final s = readState();
      expect(s.selectedServerId, isNull);
    });

    test('selectServer updates state and persists', () async {
      await readStore().selectServer('server-1');

      expect(readState().selectedServerId, 'server-1');
      expect(
        fakeStorage.snapshot[ServerSelectionStorageKeys.selectedServerId],
        'server-1',
      );
    });

    test('selectServer overwrites previous selection', () async {
      await readStore().selectServer('server-1');
      await readStore().selectServer('server-2');

      expect(readState().selectedServerId, 'server-2');
      expect(
        fakeStorage.snapshot[ServerSelectionStorageKeys.selectedServerId],
        'server-2',
      );
    });

    test('restoreSelection reads from storage', () async {
      fakeStorage._store[ServerSelectionStorageKeys.selectedServerId] =
          'stored-server';

      await readStore().restoreSelection();

      expect(readState().selectedServerId, 'stored-server');
    });

    test('restoreSelection with empty storage keeps null', () async {
      await readStore().restoreSelection();

      expect(readState().selectedServerId, isNull);
    });

    test('restoreSelection clears stale in-memory state when storage empty',
        () async {
      await readStore().selectServer('stale-server');
      expect(readState().selectedServerId, 'stale-server');

      await ServerSelectionStorageKeys.clear(fakeStorage);

      await readStore().restoreSelection();

      expect(readState().selectedServerId, isNull);
    });

    test('restoreSelection falls back to null on storage read exception',
        () async {
      await readStore().selectServer('pre-existing');
      expect(readState().selectedServerId, 'pre-existing');

      fakeStorage.shouldThrow = true;

      await readStore().restoreSelection();

      expect(readState().selectedServerId, isNull);
    });

    test('clearSelection clears state and storage', () async {
      await readStore().selectServer('to-clear');
      expect(readState().selectedServerId, 'to-clear');

      await readStore().clearSelection();

      expect(readState().selectedServerId, isNull);
      expect(
        fakeStorage.snapshot[ServerSelectionStorageKeys.selectedServerId],
        isNull,
      );
    });

    test('clearSelection does not clear non-selection keys', () async {
      fakeStorage._store['other_key'] = 'other_value';

      await readStore().selectServer('server-1');
      await readStore().clearSelection();

      expect(fakeStorage.snapshot['other_key'], 'other_value');
    });

    test('full lifecycle: select -> restore -> clear -> restore', () async {
      await readStore().selectServer('server-1');
      expect(readState().selectedServerId, 'server-1');

      // Simulate app restart.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
      );

      await readStore().restoreSelection();
      expect(readState().selectedServerId, 'server-1');

      await readStore().clearSelection();
      expect(readState().selectedServerId, isNull);

      // Another restart after clear.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
      );

      await readStore().restoreSelection();
      expect(readState().selectedServerId, isNull);
    });
  });

  group('ServerSelectionState', () {
    test('copyWith preserves fields when not overridden', () {
      const original = ServerSelectionState(selectedServerId: 'server-1');

      final copied = original.copyWith();

      expect(copied, equals(original));
    });

    test('copyWith clearSelectedServerId nulls out field', () {
      const original = ServerSelectionState(selectedServerId: 'server-1');

      final cleared = original.copyWith(clearSelectedServerId: true);

      expect(cleared.selectedServerId, isNull);
    });

    test('equality and hashCode', () {
      const a = ServerSelectionState(selectedServerId: 'server-1');
      const b = ServerSelectionState(selectedServerId: 'server-1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different selectedServerId', () {
      const a = ServerSelectionState(selectedServerId: 'server-1');
      const b = ServerSelectionState(selectedServerId: 'server-2');
      expect(a, isNot(equals(b)));
    });
  });
}

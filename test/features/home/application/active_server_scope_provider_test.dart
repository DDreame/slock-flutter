import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

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

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('returns null when no server is selected', () {
    expect(container.read(activeServerScopeIdProvider), isNull);
  });

  test('returns ServerScopeId when server is selected', () async {
    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('my-server');

    expect(
      container.read(activeServerScopeIdProvider),
      const ServerScopeId('my-server'),
    );
  });

  test('updates reactively when selection changes', () async {
    expect(container.read(activeServerScopeIdProvider), isNull);

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('server-a');

    expect(
      container.read(activeServerScopeIdProvider),
      const ServerScopeId('server-a'),
    );

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('server-b');

    expect(
      container.read(activeServerScopeIdProvider),
      const ServerScopeId('server-b'),
    );
  });

  test('returns null after selection is cleared', () async {
    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer('my-server');

    expect(container.read(activeServerScopeIdProvider), isNotNull);

    await container
        .read(serverSelectionStoreProvider.notifier)
        .clearSelection();

    expect(container.read(activeServerScopeIdProvider), isNull);
  });
}

import 'package:slock_app/core/storage/secure_storage.dart';

/// Shared fake [SecureStorage] for tests.
///
/// In-memory key–value store. Exposes [store] for direct inspection
/// and [snapshot] for a read-only copy.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  /// Read-only snapshot of the current store contents.
  Map<String, String> get snapshot => Map.unmodifiable(store);

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

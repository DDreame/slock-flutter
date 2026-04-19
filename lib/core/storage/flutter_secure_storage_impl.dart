import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:slock_app/core/storage/secure_storage.dart';

class FlutterSecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

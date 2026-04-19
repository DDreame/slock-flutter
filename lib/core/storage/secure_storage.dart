import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/storage/flutter_secure_storage_impl.dart';

abstract class SecureStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return FlutterSecureStorageImpl();
});

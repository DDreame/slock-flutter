import 'package:slock_app/core/storage/secure_storage.dart';

abstract final class ServerSelectionStorageKeys {
  static const selectedServerId = 'server_selection_selected_server_id';

  static const _all = [selectedServerId];

  static Future<void> clear(SecureStorage storage) async {
    for (final key in _all) {
      await storage.delete(key: key);
    }
  }
}

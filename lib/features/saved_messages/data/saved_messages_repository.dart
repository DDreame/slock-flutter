import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';

abstract class SavedMessagesRepository {
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  });

  Future<void> saveMessage(
    ServerScopeId serverId,
    String messageId,
  );

  Future<void> unsaveMessage(
    ServerScopeId serverId,
    String messageId,
  );

  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  );
}

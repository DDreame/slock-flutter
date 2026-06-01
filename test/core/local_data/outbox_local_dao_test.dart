import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/local_data/local_data.dart';

Future<AppDatabase?> _tryOpenMemoryDb() async {
  AppDatabase? database;
  try {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    return database;
  } catch (_) {
    await database?.close();
    return null;
  }
}

void main() {
  Future<OutboxLocalStore?> openStore() async {
    final database = await _tryOpenMemoryDb();
    if (database == null) return null;
    addTearDown(database.close);
    return database.outboxLocalDao;
  }

  test('replaceAll and loadAll preserve queued outbox fields by target',
      () async {
    final store = await openStore();
    if (store == null) {
      markTestSkipped('sqlite3 native library not available');
      return;
    }
    final createdAt = DateTime.parse('2026-06-01T12:00:00Z');

    await store.replaceAll({
      'channel/server-1/general': [
        LocalOutboxEntry(
          targetKey: 'channel/server-1/general',
          localId: 'local-1',
          content: 'Queued channel message',
          createdAt: createdAt,
          replyToId: 'msg-parent',
          status: 'failed',
          failureMessage: 'network unavailable',
          retryCount: 3,
        ),
      ],
      'directMessage/server-1/dm-1': [
        LocalOutboxEntry(
          targetKey: 'directMessage/server-1/dm-1',
          localId: 'local-2',
          content: 'Queued DM message',
          createdAt: createdAt.add(const Duration(seconds: 1)),
          status: 'pending',
        ),
      ],
    });

    final stored = await store.loadAll();

    expect(
        stored.keys,
        containsAll([
          'channel/server-1/general',
          'directMessage/server-1/dm-1',
        ]));
    final channelEntry = stored['channel/server-1/general']!.single;
    expect(channelEntry.localId, 'local-1');
    expect(channelEntry.content, 'Queued channel message');
    expect(channelEntry.createdAt, createdAt);
    expect(channelEntry.replyToId, 'msg-parent');
    expect(channelEntry.status, 'failed');
    expect(channelEntry.failureMessage, 'network unavailable');
    expect(channelEntry.retryCount, 3);

    final dmEntry = stored['directMessage/server-1/dm-1']!.single;
    expect(dmEntry.localId, 'local-2');
    expect(dmEntry.content, 'Queued DM message');
    expect(dmEntry.status, 'pending');
    expect(dmEntry.retryCount, 0);
  });

  test('replaceAll atomically replaces old rows and clearAll removes rows',
      () async {
    final store = await openStore();
    if (store == null) {
      markTestSkipped('sqlite3 native library not available');
      return;
    }

    await store.replaceAll({
      'channel/server-1/old': [
        LocalOutboxEntry(
          targetKey: 'channel/server-1/old',
          localId: 'old-1',
          content: 'Old message',
          createdAt: DateTime.parse('2026-06-01T12:00:00Z'),
          status: 'pending',
        ),
      ],
    });

    await store.replaceAll({
      'channel/server-1/new': [
        LocalOutboxEntry(
          targetKey: 'channel/server-1/new',
          localId: 'new-1',
          content: 'New message',
          createdAt: DateTime.parse('2026-06-01T12:01:00Z'),
          status: 'pending',
        ),
      ],
    });

    final replaced = await store.loadAll();
    expect(replaced.keys, ['channel/server-1/new']);
    expect(replaced['channel/server-1/new']!.single.content, 'New message');

    await store.clearAll();

    expect(await store.loadAll(), isEmpty);
  });
}

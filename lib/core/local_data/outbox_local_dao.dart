part of 'app_database.dart';

@DriftAccessor(tables: [OutboxEntries])
class OutboxLocalDao extends DatabaseAccessor<AppDatabase>
    with _$OutboxLocalDaoMixin
    implements OutboxLocalStore {
  OutboxLocalDao(super.attachedDatabase);

  @override
  Future<Map<String, List<LocalOutboxEntry>>> loadAll() async {
    final rows = await (select(outboxEntries)
          ..orderBy([
            (table) => OrderingTerm.asc(table.targetKey),
            (table) => OrderingTerm.asc(table.createdAt),
          ]))
        .get();
    final result = <String, List<LocalOutboxEntry>>{};
    for (final row in rows) {
      result.putIfAbsent(row.targetKey, () => []).add(_outboxEntryFromRow(row));
    }
    return result;
  }

  @override
  Future<void> replaceAll(Map<String, List<LocalOutboxEntry>> items) async {
    await transaction(() async {
      await delete(outboxEntries).go();
      final flattened = [
        for (final entry in items.entries)
          for (final item in entry.value) item,
      ];
      if (flattened.isEmpty) return;
      await batch((batch) {
        for (final item in flattened) {
          batch.insert(
            outboxEntries,
            OutboxEntriesCompanion.insert(
              targetKey: item.targetKey,
              localId: item.localId,
              content: item.content,
              createdAt: item.createdAt,
              replyToId: Value(item.replyToId),
              status: item.status,
              failureMessage: Value(item.failureMessage),
              retryCount: Value(item.retryCount),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  @override
  Future<void> clearAll() async {
    await delete(outboxEntries).go();
  }

  LocalOutboxEntry _outboxEntryFromRow(OutboxEntry row) {
    return LocalOutboxEntry(
      targetKey: row.targetKey,
      localId: row.localId,
      content: row.content,
      createdAt: row.createdAt,
      replyToId: row.replyToId,
      status: row.status,
      failureMessage: row.failureMessage,
      retryCount: row.retryCount,
    );
  }
}

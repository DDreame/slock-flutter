import 'package:drift/backends.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/local_data/local_data.dart';

void main() {
  group('ConversationLocalDao.removeConversationSummariesNotIn', () {
    test('uses one scoped DELETE with NOT IN for retained ids', () async {
      final executor = _RecordingExecutor();
      final database = AppDatabase(executor);
      addTearDown(database.close);

      await database.conversationLocalDao.removeConversationSummariesNotIn(
        serverId: 'server-a',
        surface: 'channel',
        retainedConversationIds: {'keep-channel', 'keep-channel-2'},
      );

      expect(executor.deletes, hasLength(1));
      expect(executor.selects, isEmpty);
      expect(executor.batches, isEmpty);
      expect(
        executor.deletes.single.statement,
        contains('DELETE FROM "conversation_summaries"'),
      );
      expect(executor.deletes.single.statement, contains('"server_id" = ?'));
      expect(executor.deletes.single.statement, contains('"surface" = ?'));
      expect(
        executor.deletes.single.statement,
        contains('"conversation_id" NOT IN (?, ?)'),
      );
      expect(
        executor.deletes.single.args,
        ['server-a', 'channel', 'keep-channel', 'keep-channel-2'],
      );
    });

    test('uses one scoped DELETE without NOT IN for an empty retain set',
        () async {
      final executor = _RecordingExecutor();
      final database = AppDatabase(executor);
      addTearDown(database.close);

      await database.conversationLocalDao.removeConversationSummariesNotIn(
        serverId: 'server-a',
        surface: 'channel',
        retainedConversationIds: const {},
      );

      expect(executor.deletes, hasLength(1));
      expect(executor.selects, isEmpty);
      expect(executor.batches, isEmpty);
      expect(
        executor.deletes.single.statement,
        contains('DELETE FROM "conversation_summaries"'),
      );
      expect(executor.deletes.single.statement, contains('"server_id" = ?'));
      expect(executor.deletes.single.statement, contains('"surface" = ?'));
      expect(executor.deletes.single.statement, isNot(contains('NOT IN')));
      expect(executor.deletes.single.args, ['server-a', 'channel']);
    });
  });
}

class _RecordingExecutor implements QueryExecutor {
  final List<_SqlCall> deletes = [];
  final List<_SqlCall> selects = [];
  final List<BatchedStatements> batches = [];

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    selects.add(_SqlCall(statement, args));
    return const [];
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    deletes.add(_SqlCall(statement, args));
    return 1;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    throw UnsupportedError('runInsert is not used by these tests');
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    throw UnsupportedError('runUpdate is not used by these tests');
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    throw UnsupportedError('runCustom is not used by these tests');
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    batches.add(statements);
  }

  @override
  TransactionExecutor beginTransaction() {
    throw UnsupportedError('beginTransaction is not used by these tests');
  }

  @override
  QueryExecutor beginExclusive() => this;
}

class _SqlCall {
  const _SqlCall(this.statement, this.args);

  final String statement;
  final List<Object?> args;
}

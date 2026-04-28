import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

void main() {
  test('loadServers returns list from loader', () async {
    const expected = [
      ServerSummary(id: 'server-1', name: 'Workspace A'),
      ServerSummary(id: 'server-2', name: 'Workspace B'),
    ];
    final repository = BaselineServerListRepository(
      loadServers: () async => expected,
    );

    final result = await repository.loadServers();
    expect(result, expected);
  });

  test('loadServers rethrows AppFailure from loader', () async {
    const failure = ServerFailure(
      message: 'Server list failed.',
      statusCode: 500,
    );
    final repository = BaselineServerListRepository(
      loadServers: () async => throw failure,
    );

    expect(
      () => repository.loadServers(),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('loadServers wraps non-AppFailure in UnknownFailure', () async {
    final repository = BaselineServerListRepository(
      loadServers: () async => throw Exception('boom'),
    );

    expect(
      () => repository.loadServers(),
      throwsA(
        isA<UnknownFailure>().having(
          (f) => f.message,
          'message',
          'Failed to load server list.',
        ),
      ),
    );
  });

  test('ServerSummary equality', () {
    const a = ServerSummary(id: 'x', name: 'X');
    const b = ServerSummary(id: 'x', name: 'X');
    const c = ServerSummary(id: 'y', name: 'Y');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('ServerSummary equality includes slug and role', () {
    const a = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'owner');
    const b = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'owner');
    const c = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'member');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('ServerSummary role helpers', () {
    const owner = ServerSummary(id: 'x', name: 'X', role: 'owner');
    const admin = ServerSummary(id: 'x', name: 'X', role: 'admin');
    const member = ServerSummary(id: 'x', name: 'X', role: 'member');
    const unknown = ServerSummary(id: 'x', name: 'X');

    expect(owner.isOwner, isTrue);
    expect(owner.isAdmin, isTrue);
    expect(admin.isOwner, isFalse);
    expect(admin.isAdmin, isTrue);
    expect(member.isOwner, isFalse);
    expect(member.isAdmin, isFalse);
    expect(unknown.isOwner, isFalse);
    expect(unknown.isAdmin, isFalse);
  });

  test('ServerSummary defaults for optional fields', () {
    const server = ServerSummary(id: 'x', name: 'X');
    expect(server.slug, '');
    expect(server.role, '');
    expect(server.createdAt, isNull);
  });
}

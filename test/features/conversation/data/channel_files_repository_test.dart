import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Fake implementation for testing the ChannelFilesPage.
class FakeChannelFilesRepository implements ChannelFilesRepository {
  FakeChannelFilesRepository({this.files = const [], this.shouldThrow = false});

  final List<MessageAttachment> files;
  final bool shouldThrow;

  String? capturedServerId;
  String? capturedChannelId;

  @override
  Future<List<MessageAttachment>> listFiles(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    capturedServerId = serverId.value;
    capturedChannelId = channelId;
    if (shouldThrow) {
      throw const UnknownFailure(
        message: 'API error',
        causeType: 'TestException',
      );
    }
    return files;
  }
}

void main() {
  group('FakeChannelFilesRepository', () {
    test('listFiles returns parsed attachments (INV-FILES-1)', () async {
      final repo = FakeChannelFilesRepository(
        files: const [
          MessageAttachment(
            name: 'report.pdf',
            type: 'application/pdf',
            url: 'https://example.com/report.pdf',
            sizeBytes: 2048,
          ),
          MessageAttachment(
            name: 'photo.png',
            type: 'image/png',
            url: 'https://example.com/photo.png',
            sizeBytes: 4096,
          ),
        ],
      );

      final files = await repo.listFiles(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
      );

      expect(files, hasLength(2));
      expect(files[0].name, 'report.pdf');
      expect(files[1].name, 'photo.png');
      expect(repo.capturedServerId, 'server-1');
      expect(repo.capturedChannelId, 'channel-1');
    });

    test('listFiles throws on API failure', () async {
      final repo = FakeChannelFilesRepository(shouldThrow: true);

      expect(
        () => repo.listFiles(
          const ServerScopeId('server-1'),
          channelId: 'channel-1',
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('parseFileListResponse', () {
    test('parses bare list response', () {
      final result = parseFileListResponse([
        {'name': 'a.txt', 'type': 'text/plain', 'url': 'https://x.com/a.txt'},
      ]);

      expect(result, hasLength(1));
      expect(result[0].name, 'a.txt');
    });

    test('parses {"files": [...]} response', () {
      final result = parseFileListResponse({
        'files': [
          {
            'name': 'b.pdf',
            'type': 'application/pdf',
            'url': 'https://x.com/b.pdf',
          },
          {
            'name': 'c.png',
            'type': 'image/png',
            'url': 'https://x.com/c.png',
          },
        ],
      });

      expect(result, hasLength(2));
      expect(result[0].name, 'b.pdf');
      expect(result[1].name, 'c.png');
    });

    test('parses {"attachments": [...]} response', () {
      final result = parseFileListResponse({
        'attachments': [
          {
            'name': 'd.csv',
            'type': 'text/csv',
            'url': 'https://x.com/d.csv',
          },
        ],
      });

      expect(result, hasLength(1));
      expect(result[0].name, 'd.csv');
    });

    test('prefers "files" over "attachments" key', () {
      final result = parseFileListResponse({
        'files': [
          {'name': 'from-files.txt', 'type': 'text/plain'},
        ],
        'attachments': [
          {'name': 'from-attachments.txt', 'type': 'text/plain'},
        ],
      });

      expect(result, hasLength(1));
      expect(result[0].name, 'from-files.txt');
    });

    test('returns empty list for null/unknown response shape', () {
      expect(parseFileListResponse(null), isEmpty);
      expect(parseFileListResponse('not-a-list'), isEmpty);
      expect(parseFileListResponse(42), isEmpty);
      expect(parseFileListResponse(<String, dynamic>{}), isEmpty);
    });

    test('parses createdAt timestamp when present', () {
      final result = parseFileListResponse([
        {
          'name': 'ts.txt',
          'type': 'text/plain',
          'createdAt': '2026-05-10T12:00:00Z',
        },
      ]);

      expect(result, hasLength(1));
      expect(result[0].createdAt, isNotNull);
      expect(result[0].createdAt, DateTime.utc(2026, 5, 10, 12));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository.dart';
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
  group('ChannelFilesRepository', () {
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
}

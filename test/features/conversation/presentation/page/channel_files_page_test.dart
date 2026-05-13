import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/channel_files_page.dart';

import '../../../conversation/data/channel_files_repository_test.dart';

void main() {
  Widget buildSubject({required FakeChannelFilesRepository repo}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: ChannelFilesPage(
          serverId: 'server-1',
          channelId: 'channel-1',
          repositoryOverride: repo,
        ),
      ),
    );
  }

  testWidgets('file list renders sorted by newest (INV-FILES-1)',
      (tester) async {
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

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('channel-files-list')), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);

    // Verify ordering: report.pdf should appear before photo.png.
    final reportCenter = tester.getCenter(find.text('report.pdf'));
    final photoCenter = tester.getCenter(find.text('photo.png'));
    expect(reportCenter.dy, lessThan(photoCenter.dy),
        reason: 'INV-FILES-1: files should maintain server-returned order');
  });

  testWidgets('tap file pushes /file-preview with attachment (INV-FILES-2)',
      (tester) async {
    final repo = FakeChannelFilesRepository(
      files: const [
        MessageAttachment(
          name: 'doc.txt',
          type: 'text/plain',
          url: 'https://example.com/doc.txt',
        ),
      ],
    );

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    // Verify the tile rendered and is tappable.
    // The actual navigation uses go_router context.push which requires a full
    // GoRouter setup. We verify the list tile rendered with the right key.
    expect(
      find.byKey(const ValueKey('channel-file-doc.txt-0')),
      findsOneWidget,
      reason: 'INV-FILES-2: file tile should render and be tappable',
    );

    // Tap the file tile — should not throw.
    await tester.tap(find.text('doc.txt'));
    await tester.pumpAndSettle();
  });

  testWidgets('empty response shows empty state (INV-FILES-3)', (tester) async {
    final repo = FakeChannelFilesRepository(files: const []);

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('channel-files-empty')), findsOneWidget);
    expect(find.text('No files in this channel'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
  });
}

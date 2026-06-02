import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/channel_files_page.dart';

import '../../../conversation/data/channel_files_repository_test.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  /// Builds a test harness with a real GoRouter so context.push works.
  Widget buildSubject({
    required FakeChannelFilesRepository repo,
    void Function(MessageAttachment)? onFilePreview,
  }) {
    final router = GoRouter(
      initialLocation: '/files',
      routes: [
        GoRoute(
          path: '/files',
          builder: (context, state) => ChannelFilesPage(
            serverId: 'server-1',
            channelId: 'channel-1',
            listFilesOverride: repo.listFiles,
          ),
        ),
        GoRoute(
          path: '/file-preview',
          builder: (context, state) {
            final attachment = state.extra as MessageAttachment;
            onFilePreview?.call(attachment);
            return Scaffold(
              body: Text('preview:${attachment.name}'),
            );
          },
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }

  testWidgets('file list sorts by createdAt newest-first (INV-FILES-1)',
      (tester) async {
    // Provide files in oldest-first order — page should reverse to newest-first.
    final repo = FakeChannelFilesRepository(
      files: [
        MessageAttachment(
          name: 'old.pdf',
          type: 'application/pdf',
          url: 'https://example.com/old.pdf',
          createdAt: DateTime(2026, 1, 1),
        ),
        MessageAttachment(
          name: 'new.png',
          type: 'image/png',
          url: 'https://example.com/new.png',
          createdAt: DateTime(2026, 5, 10),
        ),
        MessageAttachment(
          name: 'mid.txt',
          type: 'text/plain',
          url: 'https://example.com/mid.txt',
          createdAt: DateTime(2026, 3, 15),
        ),
      ],
    );

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('channel-files-list')), findsOneWidget);

    // Verify newest→oldest order: new.png, mid.txt, old.pdf.
    final newCenter = tester.getCenter(find.text('new.png'));
    final midCenter = tester.getCenter(find.text('mid.txt'));
    final oldCenter = tester.getCenter(find.text('old.pdf'));
    expect(newCenter.dy, lessThan(midCenter.dy),
        reason: 'INV-FILES-1: newest file should appear first');
    expect(midCenter.dy, lessThan(oldCenter.dy),
        reason: 'INV-FILES-1: files should be sorted newest→oldest');
  });

  testWidgets(
      'tap file navigates to /file-preview with attachment (INV-FILES-2)',
      (tester) async {
    MessageAttachment? capturedAttachment;

    final repo = FakeChannelFilesRepository(
      files: const [
        MessageAttachment(
          name: 'doc.txt',
          type: 'text/plain',
          url: 'https://example.com/doc.txt',
        ),
      ],
    );

    await tester.pumpWidget(
      buildSubject(
        repo: repo,
        onFilePreview: (attachment) => capturedAttachment = attachment,
      ),
    );
    await tester.pumpAndSettle();

    // Tap the file tile.
    await tester.tap(find.text('doc.txt'));
    await tester.pumpAndSettle();

    // Should navigate to file-preview and pass the attachment.
    expect(find.text('preview:doc.txt'), findsOneWidget,
        reason: 'INV-FILES-2: tap should navigate to /file-preview');
    expect(capturedAttachment?.name, 'doc.txt',
        reason: 'INV-FILES-2: attachment should be passed as extra');
    expect(capturedAttachment?.type, 'text/plain');
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

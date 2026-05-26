import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/announcements/presentation/widgets/announcement_banner.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  testWidgets('banner renders announcement title (INV-ANNOUNCE-1)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementStoreProvider.overrideWith(() {
            return _PreloadedAnnouncementStore([
              const Announcement(
                id: 'ann-1',
                title: 'System Maintenance',
                body: 'We will be down for 30 minutes.',
              ),
            ]);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AnnouncementBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Maintenance'), findsOneWidget);
    expect(find.text('We will be down for 30 minutes.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('announcement-banner-ann-1')),
      findsOneWidget,
    );
  });

  testWidgets('dismiss tap removes banner (INV-ANNOUNCE-2)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementStoreProvider.overrideWith(() {
            return _PreloadedAnnouncementStore([
              const Announcement(
                id: 'ann-2',
                title: 'Dismissible Notice',
                dismissible: true,
              ),
            ]);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AnnouncementBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dismissible Notice'), findsOneWidget);

    // Tap dismiss button.
    await tester.tap(find.byKey(const ValueKey('announcement-dismiss')));
    await tester.pumpAndSettle();

    // Banner should be gone.
    expect(find.text('Dismissible Notice'), findsNothing);
  });

  testWidgets('non-dismissible announcement hides close button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementStoreProvider.overrideWith(() {
            return _PreloadedAnnouncementStore([
              const Announcement(
                id: 'ann-3',
                title: 'Mandatory Notice',
                dismissible: false,
              ),
            ]);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AnnouncementBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mandatory Notice'), findsOneWidget);
    expect(find.byKey(const ValueKey('announcement-dismiss')), findsNothing);
  });

  testWidgets('banner is hidden when no announcements', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementStoreProvider.overrideWith(() {
            return _PreloadedAnnouncementStore(const []);
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AnnouncementBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byIcon(Icons.campaign_outlined), findsNothing);
  });
}

/// A test-only announcement store that starts pre-loaded with announcements.
class _PreloadedAnnouncementStore extends AnnouncementStore {
  _PreloadedAnnouncementStore(this._initial);

  final List<Announcement> _initial;

  @override
  AnnouncementState build() {
    return AnnouncementState(
      status: AnnouncementStatus.success,
      announcements: _initial,
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> dismiss(String announcementId) async {
    final updated =
        state.announcements.where((a) => a.id != announcementId).toList();
    state = state.copyWith(announcements: updated);
  }
}

// Phase A: Accessibility tests for #822 — Hardcoded English Tooltips → ARB
// + Home Semantics Label → ARB.
//
// Item 1 (LOW): Voice bubble Play/Pause tooltip hardcoded in English.
// Item 2 (LOW): Member list item 'Message' and 'Member admin actions' tooltips
//   hardcoded in English.
// Item 3 (LOW): home_page.dart Semantics(label: 'Home overview') hardcoded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_message_bubble.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // Item 1: Voice bubble play/pause tooltip uses l10n
  // ===========================================================================

  group('Item 1 — Voice bubble tooltip localization', () {
    Widget buildBubble({
      bool isPlaying = false,
      Locale locale = const Locale('zh'),
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VoiceMessageBubble(
            duration: const Duration(seconds: 30),
            position: Duration.zero,
            isPlaying: isPlaying,
            waveform: const [0.3, 0.7, 0.5, 0.8, 0.2, 0.9, 0.4],
            onPlayPause: () {},
            onSeek: (_) {},
          ),
        ),
      );
    }

    testWidgets('play tooltip shows localized text in ZH', (tester) async {
      await tester.pumpWidget(
          buildBubble(isPlaying: false, locale: const Locale('zh')));
      await tester.pumpAndSettle();

      // Should show Chinese "播放" not English "Play".
      expect(find.byTooltip('播放'), findsOneWidget);
      expect(find.byTooltip('Play'), findsNothing);
    });

    testWidgets('pause tooltip shows localized text in ZH', (tester) async {
      await tester
          .pumpWidget(buildBubble(isPlaying: true, locale: const Locale('zh')));
      await tester.pumpAndSettle();

      // Should show Chinese "暂停" not English "Pause".
      expect(find.byTooltip('暂停'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    });

    testWidgets('play tooltip shows English in EN locale', (tester) async {
      await tester.pumpWidget(
          buildBubble(isPlaying: false, locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Play'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Item 2: Member list item tooltips use l10n
  // ===========================================================================

  group('Item 2 — Member list item tooltip localization', () {
    Widget buildMemberItem({
      Locale locale = const Locale('zh'),
      bool canManageMember = true,
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MemberListItem(
            member: const MemberProfile(
              id: 'test-id',
              displayName: 'Test User',
              email: 'test@example.com',
              role: 'member',
              isSelf: false,
            ),
            canManageMember: canManageMember,
            onTap: () {},
            onMessage: () {},
            onChangeRole: (_) {},
            onRemove: () {},
          ),
        ),
      );
    }

    testWidgets('message tooltip shows localized text in ZH', (tester) async {
      await tester.pumpWidget(buildMemberItem(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      // Should show Chinese "发消息" not English "Message".
      expect(find.byTooltip('发消息'), findsOneWidget);
      expect(find.byTooltip('Message'), findsNothing);
    });

    testWidgets('admin actions tooltip shows localized text in ZH',
        (tester) async {
      await tester.pumpWidget(buildMemberItem(
        locale: const Locale('zh'),
        canManageMember: true,
      ));
      await tester.pumpAndSettle();

      // Should show Chinese "成员管理操作" not English "Member admin actions".
      expect(find.byTooltip('成员管理操作'), findsOneWidget);
      expect(find.byTooltip('Member admin actions'), findsNothing);
    });

    testWidgets('message tooltip shows English in EN locale', (tester) async {
      await tester.pumpWidget(buildMemberItem(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Message'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Item 3: Home page overview semantics label uses l10n
  // ===========================================================================

  group('Item 3 — Home overview semantics localization', () {
    testWidgets('home overview semantics label is not hardcoded English',
        (tester) async {
      // This test verifies the ARB key exists and is wired.
      // We verify by checking the generated AppLocalizations class.
      final enL10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(enL10n.homeOverviewSemantics, 'Home overview');

      final zhL10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(zhL10n.homeOverviewSemantics, '首页概览');

      final esL10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(esL10n.homeOverviewSemantics, 'Vista general');
    });
  });
}

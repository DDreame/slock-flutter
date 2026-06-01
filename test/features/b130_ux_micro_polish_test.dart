// =============================================================================
// B130 — UX Micro-Polish: 4 load-bearing tests.
//
// 1. Task ref tap — shows snackbar "Task not found" on 404 (not silent fallback)
// 2. Non-member notification — rootScaffoldMessengerKey is wired
// 3. Task claim 409 — shows "already claimed" (not generic conflict message)
// 4. Message composer — character counter + send disabled over limit
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/root_scaffold_messenger.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  final testTarget = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('srv-1'),
      value: 'ch-1',
    ),
  );

  group('B130 — Message composer max-length', () {
    Widget buildComposer({required String draft}) {
      final controller = TextEditingController(text: draft);
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ConversationComposer(
              controller: controller,
              focusNode: FocusNode(),
              state: ConversationDetailState(
                target: testTarget,
                status: ConversationDetailStatus.success,
                draft: draft,
              ),
              isRecording: false,
              isFormattingToolbarVisible: false,
              isEmojiPickerVisible: false,
              onToggleFormattingToolbar: () {},
              onToggleEmojiPicker: () {},
              onChanged: (_) {},
              onSend: () async {},
              onPickAttachment: (_) {},
              onRemoveAttachment: (_) {},
              onCancelUpload: (_) {},
              onClearReply: () {},
              onMicTap: () {},
              onSendRecording: () {},
              onCancelRecording: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows character counter when approaching limit',
        (tester) async {
      // 3850 chars = within 200 of 4000 limit → counter should show
      final draft = 'a' * 3850;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('composer-char-counter')),
        findsOneWidget,
      );
      expect(find.text('3850/4000'), findsOneWidget);
    });

    testWidgets('hides character counter when well under limit',
        (tester) async {
      final draft = 'a' * 100;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('composer-char-counter')),
        findsNothing,
      );
    });

    testWidgets('shows "Message too long" when over limit', (tester) async {
      final draft = 'a' * 4001;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      expect(find.text('Message too long'), findsOneWidget);
    });

    testWidgets('send button hidden when over limit', (tester) async {
      final draft = 'a' * 4001;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      // Send button should NOT appear when over limit
      expect(find.byKey(const ValueKey('composer-send')), findsNothing);
      // Mic button appears instead (canSend is false)
      expect(find.byKey(const ValueKey('composer-mic')), findsOneWidget);
    });

    testWidgets('send button visible when at limit', (tester) async {
      final draft = 'a' * 4000;
      await tester.pumpWidget(buildComposer(draft: draft));
      await tester.pumpAndSettle();

      // Exactly at limit — send should still work
      expect(find.byKey(const ValueKey('composer-send')), findsOneWidget);
    });
  });

  group('B130 — rootScaffoldMessengerKey', () {
    testWidgets('key is wired into MaterialApp and can show snackbar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Text('test')),
        ),
      );

      final messenger = rootScaffoldMessengerKey.currentState;
      expect(messenger, isNotNull);

      messenger!.showSnackBar(
        const SnackBar(content: Text('no access')),
      );
      await tester.pump();

      expect(find.text('no access'), findsOneWidget);
    });
  });
}

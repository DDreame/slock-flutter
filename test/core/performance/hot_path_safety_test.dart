import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/presentation/widgets/mention_syntax.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

void main() {
  group('Hot-path RegExp constants', () {
    test(
      'INV-REGEXP-MENTION-1: mentionSpanRegex is a shared module-level '
      'constant with correct pattern',
      () {
        // The constant must be a single compiled RegExp shared across
        // all calls to buildMentionAwareSpan, not allocated per call.
        expect(mentionSpanRegex, isA<RegExp>());

        // Same instance on repeated access (module-level final).
        expect(identical(mentionSpanRegex, mentionSpanRegex), isTrue);

        // Pattern correctness: matches @mention at word boundary.
        expect(mentionSpanRegex.hasMatch('@alice'), isTrue);
        expect(mentionSpanRegex.hasMatch('@Bob-123'), isTrue);

        // Does not match inside email addresses (preceded by word char).
        expect(mentionSpanRegex.hasMatch('user@domain.com'), isFalse);
      },
      skip: true,
    );

    test(
      'INV-REGEXP-INITIALS-1: dmRowInitialsRegex is a shared module-level '
      'constant for DM row initials extraction',
      () {
        expect(dmRowInitialsRegex, isA<RegExp>());
        expect(identical(dmRowInitialsRegex, dmRowInitialsRegex), isTrue);

        // Splits on whitespace.
        expect('Hello World'.split(dmRowInitialsRegex), ['Hello', 'World']);
        expect('A  B'.split(dmRowInitialsRegex), ['A', 'B']);
      },
      skip: true,
    );

    test(
      'INV-REGEXP-SHARE-1: sharePickerInitialsRegex is a shared module-level '
      'constant for share picker initials extraction',
      () {
        expect(sharePickerInitialsRegex, isA<RegExp>());
        expect(
          identical(sharePickerInitialsRegex, sharePickerInitialsRegex),
          isTrue,
        );

        // Splits on whitespace (same pattern as DM row).
        expect(
          'Hello World'.split(sharePickerInitialsRegex),
          ['Hello', 'World'],
        );
        expect('A  B'.split(sharePickerInitialsRegex), ['A', 'B']);
      },
      skip: true,
    );
  });

  group('Mounted guard on deferred mark-read', () {
    test(
      'INV-MOUNTED-CHANNEL-1: channels_tab mark-read delayed callback '
      'is guarded by mounted check',
      () {
        // Phase B will:
        // 1. Render ChannelsTabPage inside ProviderScope with mock
        //    markChannelReadUseCaseProvider that records invocations.
        // 2. Tap a channel row to trigger Future.delayed(1s, mark-read).
        // 3. pumpWidget(Container()) to dispose ChannelsTabPage.
        // 4. fakeAsync: elapse 2 seconds past the delay.
        // 5. Verify the mock mark-read was NOT invoked after disposal —
        //    the mounted guard prevents ref.read() after widget dispose.
      },
      skip: true,
    );

    test(
      'INV-MOUNTED-DM-1: dms_tab mark-read delayed callback '
      'is guarded by mounted check',
      () {
        // Phase B will:
        // 1. Render DmsTabPage inside ProviderScope with mock
        //    markDmReadUseCaseProvider that records invocations.
        // 2. Tap a DM row to trigger Future.delayed(1s, mark-read).
        // 3. pumpWidget(Container()) to dispose DmsTabPage.
        // 4. fakeAsync: elapse 2 seconds past the delay.
        // 5. Verify the mock mark-read was NOT invoked after disposal —
        //    the mounted guard prevents ref.read() after widget dispose.
      },
      skip: true,
    );
  });
}

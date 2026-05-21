import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  testWidgets('EditMessageDialog resets saving after non-AppFailure exception',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: EditMessageDialog(
            initialContent: 'before',
            onSave: (_) async {
              throw StateError('boom');
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-message-field')),
      'after',
    );
    await tester.pump();

    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('edit-message-save')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('edit-message-save')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Failed to edit message.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('edit-message-save')))
          .onPressed,
      isNotNull,
      reason: 'Save must be re-enabled so the dialog does not trap the user.',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('edit-message-field')))
          .enabled,
      isTrue,
    );
  });
}

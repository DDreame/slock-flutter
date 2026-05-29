import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  Widget buildDialog({
    String currentName = 'general',
    String? currentDescription,
    bool currentIsPrivate = false,
    bool isSubmitting = false,
    ValueChanged<EditChannelResult>? onSave,
    VoidCallback? onCancel,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => EditChannelDialog(
            currentName: currentName,
            currentDescription: currentDescription,
            currentIsPrivate: currentIsPrivate,
            isSubmitting: isSubmitting,
            onSave: onSave ?? (_) {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );
  }

  group('EditChannelDialog expanded fields', () {
    testWidgets('pre-fills description from currentDescription',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentDescription: 'Team discussions',
      ));
      await tester.pumpAndSettle();

      final descriptionField = tester.widget<TextField>(
        find.byKey(const ValueKey('edit-channel-description')),
      );
      expect(descriptionField.controller!.text, 'Team discussions');
    });

    testWidgets('pre-fills isPrivate switch from currentIsPrivate',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentIsPrivate: true,
      ));
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('edit-channel-private-switch')),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('save button disabled when no changes made', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Original desc',
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      // Find the Save FilledButton and check it's disabled.
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save button enabled when description changes', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Original desc',
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      // Type new description.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-description')),
        'Updated desc',
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('save button enabled when isPrivate toggled', (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: null,
        currentIsPrivate: false,
      ));
      await tester.pumpAndSettle();

      // Toggle the switch.
      await tester
          .tap(find.byKey(const ValueKey('edit-channel-private-switch')));
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('onSave receives EditChannelResult with all fields',
        (tester) async {
      EditChannelResult? receivedResult;
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
        currentDescription: 'Old desc',
        currentIsPrivate: false,
        onSave: (result) => receivedResult = result,
      ));
      await tester.pumpAndSettle();

      // Change name.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-name')),
        'engineering',
      );
      // Change description.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-description')),
        'New desc',
      );
      // Toggle private.
      await tester
          .tap(find.byKey(const ValueKey('edit-channel-private-switch')));
      await tester.pump();

      // Tap save.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(receivedResult, isNotNull);
      expect(receivedResult!.name, 'engineering');
      expect(receivedResult!.description, 'New desc');
      expect(receivedResult!.isPrivate, isTrue);
    });

    testWidgets('save button disabled when name cleared (validation)',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        currentName: 'general',
      ));
      await tester.pumpAndSettle();

      // Clear name.
      await tester.enterText(
        find.byKey(const ValueKey('edit-channel-name')),
        '',
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('ZH locale renders Chinese labels for new fields',
        (tester) async {
      await tester.pumpWidget(buildDialog(
        locale: const Locale('zh'),
      ));
      await tester.pumpAndSettle();

      // Description label must be in Chinese.
      expect(find.text('描述'), findsOneWidget);
      // English label must NOT appear.
      expect(find.text('Description'), findsNothing);
      // Private switch label must be in Chinese.
      expect(find.text('私密频道'), findsOneWidget);
      expect(find.text('Private channel'), findsNothing);
    });
  });
}

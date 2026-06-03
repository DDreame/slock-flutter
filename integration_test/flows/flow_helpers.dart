// =============================================================================
// Flow Test Helpers
//
// Common navigation helpers and assertions for integration flow tests.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

/// Tap an unread item in the home page by index.
Future<void> tapUnreadItem(WidgetTester tester, int index) async {
  final finder = find.byKey(ValueKey('unread-item-$index'));
  expect(finder, findsOneWidget, reason: 'Unread item $index should exist');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Tap the back button to navigate back.
Future<void> goBack(WidgetTester tester) async {
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    return;
  }
  // Fallback: look for the AppBar's leading widget.
  final iconBack = find.byIcon(Icons.arrow_back);
  expect(iconBack, findsOneWidget, reason: 'Back button should exist');
  await tester.tap(iconBack);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Composer helpers
// ---------------------------------------------------------------------------

/// Type text into the message composer.
Future<void> enterComposerText(WidgetTester tester, String text) async {
  final composer = find.byKey(const ValueKey('composer-input'));
  expect(composer, findsOneWidget, reason: 'Composer input should exist');
  await tester.tap(composer);
  await tester.pump();
  await tester.enterText(composer, text);
  await tester.pump();
}

/// Tap the send button in the composer.
Future<void> tapSend(WidgetTester tester) async {
  final sendButton = find.byKey(const ValueKey('composer-send'));
  expect(sendButton, findsOneWidget, reason: 'Send button should exist');
  await tester.tap(sendButton);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Assertions
// ---------------------------------------------------------------------------

/// Assert that a message with the given text is visible in the conversation.
void expectMessageVisible(String text) {
  expect(
    find.text(text),
    findsAtLeastNWidgets(1),
    reason: 'Message "$text" should be visible in the conversation',
  );
}

/// Assert that the conversation title is visible (navigation succeeded).
void expectConversationTitle(String title) {
  expect(
    find.text(title),
    findsAtLeastNWidgets(1),
    reason: 'Conversation title "$title" should be visible',
  );
}

/// Assert that the home page is visible.
void expectHomePage() {
  expect(
    find.byKey(const ValueKey('home-card-unread')),
    findsOneWidget,
    reason: 'Home page unread card should be visible',
  );
}

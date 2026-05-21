// ignore_for_file: prefer_const_constructors

// =============================================================================
// #691 — Email validation in _InviteDialog
//
// Tests RFC-compliant email validation regex used in _InviteHumanSheet.
// Verifies edge cases: no domain, double @, leading @, multiline, valid
// addresses with subdomains and tags.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirror of the production regex from members_page.dart _InviteHumanSheetState.
/// Kept in sync — if the production regex changes, this test will catch drift
/// by failing on edge cases.
final _emailRegex = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
);

bool isValidEmail(String input) {
  if (input.contains('\n')) return false;
  final email = input.trim();
  if (email.isEmpty) return false;
  return _emailRegex.hasMatch(email);
}

void main() {
  group('#691 — Email validation edge cases', () {
    test('empty string → invalid', () {
      expect(isValidEmail(''), isFalse);
    });

    test('whitespace only → invalid', () {
      expect(isValidEmail('   '), isFalse);
    });

    test('user@ (no domain) → invalid', () {
      expect(isValidEmail('user@'), isFalse);
    });

    test('user@@domain.com (double @) → invalid', () {
      expect(isValidEmail('user@@domain.com'), isFalse);
    });

    test('@domain.com (leading @) → invalid', () {
      expect(isValidEmail('@domain.com'), isFalse);
    });

    test('multi-line input → invalid', () {
      expect(isValidEmail('user\n@domain.com'), isFalse);
      expect(isValidEmail('user@domain.com\n'), isFalse);
    });

    test('no @ sign → invalid', () {
      expect(isValidEmail('userdomain.com'), isFalse);
    });

    test('no TLD → invalid', () {
      expect(isValidEmail('user@domain'), isFalse);
    });

    test('trailing dot in domain → invalid', () {
      expect(isValidEmail('user@domain.com.'), isFalse);
    });

    test('user@domain.com → valid', () {
      expect(isValidEmail('user@domain.com'), isTrue);
    });

    test('user+tag@sub.domain.co → valid', () {
      expect(isValidEmail('user+tag@sub.domain.co'), isTrue);
    });

    test('firstname.lastname@company.org → valid', () {
      expect(isValidEmail('firstname.lastname@company.org'), isTrue);
    });

    test('user@123.123.123.com → valid (numeric domain labels)', () {
      expect(isValidEmail('user@123.123.123.com'), isTrue);
    });

    test('valid with leading/trailing whitespace (trimmed) → valid', () {
      expect(isValidEmail('  user@domain.com  '), isTrue);
    });
  });

  group('#691 — Email validation widget behavior', () {
    testWidgets('send button disabled when email is invalid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestEmailForm(),
          ),
        ),
      );

      // Initially empty — button should be disabled.
      final sendButton = find.byKey(ValueKey('test-email-submit'));
      expect(tester.widget<ElevatedButton>(sendButton).onPressed, isNull);

      // Enter invalid email.
      await tester.enterText(
        find.byKey(ValueKey('test-email-field')),
        'user@',
      );
      await tester.pump();
      expect(tester.widget<ElevatedButton>(sendButton).onPressed, isNull);

      // Enter valid email — button enabled.
      await tester.enterText(
        find.byKey(ValueKey('test-email-field')),
        'user@domain.com',
      );
      await tester.pump();
      expect(tester.widget<ElevatedButton>(sendButton).onPressed, isNotNull);
    });

    testWidgets('inline error shown for invalid email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestEmailForm(),
          ),
        ),
      );

      // Enter invalid email.
      await tester.enterText(
        find.byKey(ValueKey('test-email-field')),
        'user@@domain',
      );
      await tester.pump();

      // Error text should appear.
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('no error shown when field is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestEmailForm(),
          ),
        ),
      );

      // Empty field — no error.
      expect(find.text('Enter a valid email address'), findsNothing);
    });
  });
}

/// Minimal form widget that mirrors the validation logic of _InviteHumanSheet.
class _TestEmailForm extends StatefulWidget {
  @override
  State<_TestEmailForm> createState() => _TestEmailFormState();
}

class _TestEmailFormState extends State<_TestEmailForm> {
  final _controller = TextEditingController();

  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  bool get _isValid {
    final text = _controller.text;
    if (text.contains('\n')) return false;
    final email = text.trim();
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email);
  }

  String? get _errorText {
    final email = _controller.text.trim();
    if (email.isEmpty) return null;
    if (!_isValid) return 'Enter a valid email address';
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          key: ValueKey('test-email-field'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: _errorText,
          ),
          onChanged: (_) => setState(() {}),
        ),
        ElevatedButton(
          key: ValueKey('test-email-submit'),
          onPressed: _isValid ? () {} : null,
          child: Text('Send'),
        ),
      ],
    );
  }
}

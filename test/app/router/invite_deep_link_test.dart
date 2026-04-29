import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';

void main() {
  group('isInviteDeepLink', () {
    test('matches /invite/:token', () {
      expect(isInviteDeepLink('/invite/abc123'), isTrue);
    });

    test('matches with full URL', () {
      expect(isInviteDeepLink('https://slock.ai/invite/token-xyz'), isTrue);
    });

    test('rejects bare /invite without token', () {
      expect(isInviteDeepLink('/invite/'), isFalse);
      expect(isInviteDeepLink('/invite'), isFalse);
    });

    test('rejects other paths', () {
      expect(isInviteDeepLink('/home'), isFalse);
      expect(isInviteDeepLink('/servers/abc/channels/def'), isFalse);
    });

    test('rejects nested invite paths', () {
      expect(isInviteDeepLink('/invite/abc/extra'), isFalse);
    });
  });

  group('extractInviteToken', () {
    test('extracts token from path', () {
      expect(extractInviteToken('/invite/abc123'), 'abc123');
    });

    test('extracts token from full URL', () {
      expect(
        extractInviteToken('https://slock.ai/invite/token-xyz'),
        'token-xyz',
      );
    });

    test('returns null for non-invite path', () {
      expect(extractInviteToken('/home'), isNull);
    });

    test('returns null for invite without token', () {
      expect(extractInviteToken('/invite/'), isNull);
    });
  });
}

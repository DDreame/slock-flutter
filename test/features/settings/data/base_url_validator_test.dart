import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/settings/data/base_url_validator.dart';

void main() {
  group('BaseUrlValidator.normalizeApiUrl', () {
    test('returns empty string for empty input', () {
      expect(BaseUrlValidator.normalizeApiUrl(''), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(BaseUrlValidator.normalizeApiUrl('   '), '');
    });

    test('accepts https URL', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('https://api.example.com'),
        'https://api.example.com',
      );
    });

    test('accepts http URL', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('http://localhost:3000'),
        'http://localhost:3000',
      );
    });

    test('strips trailing slash', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('https://api.example.com/'),
        'https://api.example.com',
      );
    });

    test('strips multiple trailing slashes', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('https://api.example.com///'),
        'https://api.example.com',
      );
    });

    test('rejects ws URL', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('ws://example.com'),
        null,
      );
    });

    test('rejects wss URL', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('wss://example.com'),
        null,
      );
    });

    test('rejects bare domain', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('example.com'),
        null,
      );
    });

    test('trims whitespace', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('  https://api.example.com  '),
        'https://api.example.com',
      );
    });
  });

  group('BaseUrlValidator.normalizeRealtimeUrl', () {
    test('returns empty string for empty input', () {
      expect(BaseUrlValidator.normalizeRealtimeUrl(''), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(BaseUrlValidator.normalizeRealtimeUrl('   '), '');
    });

    test('accepts ws URL', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('ws://example.com'),
        'ws://example.com',
      );
    });

    test('accepts wss URL', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('wss://example.com'),
        'wss://example.com',
      );
    });

    test('normalizes http to ws', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('http://example.com'),
        'ws://example.com',
      );
    });

    test('normalizes https to wss', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('https://example.com'),
        'wss://example.com',
      );
    });

    test('strips trailing slash', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('wss://example.com/'),
        'wss://example.com',
      );
    });

    test('rejects bare domain', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('example.com'),
        null,
      );
    });

    test('rejects ftp URL', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('ftp://example.com'),
        null,
      );
    });

    test('trims whitespace', () {
      expect(
        BaseUrlValidator.normalizeRealtimeUrl('  wss://example.com  '),
        'wss://example.com',
      );
    });
  });
}

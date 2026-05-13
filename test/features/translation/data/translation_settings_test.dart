import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  group('TranslationMode.fromString', () {
    test('parses valid mode strings', () {
      expect(TranslationMode.fromString('auto'), TranslationMode.auto);
      expect(TranslationMode.fromString('manual'), TranslationMode.manual);
      expect(TranslationMode.fromString('off'), TranslationMode.off);
    });

    test('defaults to off for unknown/null', () {
      expect(TranslationMode.fromString(null), TranslationMode.off);
      expect(TranslationMode.fromString(''), TranslationMode.off);
      expect(TranslationMode.fromString('invalid'), TranslationMode.off);
    });
  });

  group('TranslationSettings.fromMap', () {
    test('parses complete settings', () {
      final settings = TranslationSettings.fromMap({
        'preferredLanguage': 'zh',
        'preferredTimezone': 'Asia/Shanghai',
        'mode': 'auto',
      });

      expect(settings.preferredLanguage, 'zh');
      expect(settings.preferredTimezone, 'Asia/Shanghai');
      expect(settings.mode, TranslationMode.auto);
    });

    test('defaults for missing fields', () {
      final settings = TranslationSettings.fromMap({});
      expect(settings.preferredLanguage, 'en');
      expect(settings.preferredTimezone, isNull);
      expect(settings.mode, TranslationMode.off);
    });

    test('handles non-string values gracefully', () {
      final settings = TranslationSettings.fromMap({
        'preferredLanguage': 42,
        'preferredTimezone': true,
        'mode': 123,
      });
      expect(settings.preferredLanguage, 'en');
      expect(settings.preferredTimezone, isNull);
      expect(settings.mode, TranslationMode.off);
    });
  });

  group('TranslationSettings.toMap', () {
    test('serializes all fields', () {
      const settings = TranslationSettings(
        preferredLanguage: 'ja',
        preferredTimezone: 'Asia/Tokyo',
        mode: TranslationMode.manual,
      );
      final map = settings.toMap();
      expect(map['preferredLanguage'], 'ja');
      expect(map['preferredTimezone'], 'Asia/Tokyo');
      expect(map['mode'], 'manual');
    });

    test('omits null timezone', () {
      const settings = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.off,
      );
      final map = settings.toMap();
      expect(map.containsKey('preferredTimezone'), isFalse);
    });
  });

  group('TranslationSettings.copyWith', () {
    test('copies with new values', () {
      const original = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.off,
      );
      final updated = original.copyWith(
        preferredLanguage: 'fr',
        mode: TranslationMode.auto,
      );
      expect(updated.preferredLanguage, 'fr');
      expect(updated.mode, TranslationMode.auto);
    });

    test('clearTimezone removes timezone', () {
      const original = TranslationSettings(
        preferredLanguage: 'en',
        preferredTimezone: 'UTC',
        mode: TranslationMode.off,
      );
      final updated = original.copyWith(clearTimezone: true);
      expect(updated.preferredTimezone, isNull);
    });
  });

  group('TranslationSettings equality', () {
    test('equal when all fields match', () {
      const a = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.auto,
      );
      const b = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.auto,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when fields differ', () {
      const a = TranslationSettings(
        preferredLanguage: 'en',
        mode: TranslationMode.auto,
      );
      const b = TranslationSettings(
        preferredLanguage: 'zh',
        mode: TranslationMode.auto,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('TranslationStatus.fromString', () {
    test('parses valid status strings', () {
      expect(
        TranslationStatus.fromString('pending'),
        TranslationStatus.pending,
      );
      expect(
        TranslationStatus.fromString('translated'),
        TranslationStatus.translated,
      );
      expect(
        TranslationStatus.fromString('failed'),
        TranslationStatus.failed,
      );
    });

    test('defaults to pending for unknown/null', () {
      expect(TranslationStatus.fromString(null), TranslationStatus.pending);
      expect(TranslationStatus.fromString('x'), TranslationStatus.pending);
    });
  });

  group('TranslationResult.fromMap', () {
    test('parses complete result', () {
      final result = TranslationResult.fromMap({
        'messageId': 'msg-1',
        'translatedContent': 'Hola mundo',
        'sourceLanguage': 'en',
        'targetLanguage': 'es',
        'status': 'translated',
      });

      expect(result, isNotNull);
      expect(result!.messageId, 'msg-1');
      expect(result.translatedContent, 'Hola mundo');
      expect(result.sourceLanguage, 'en');
      expect(result.targetLanguage, 'es');
      expect(result.status, TranslationStatus.translated);
    });

    test('returns null for missing messageId', () {
      expect(TranslationResult.fromMap({}), isNull);
      expect(TranslationResult.fromMap({'messageId': ''}), isNull);
      expect(TranslationResult.fromMap({'messageId': 42}), isNull);
    });

    test('handles partial fields', () {
      final result = TranslationResult.fromMap({
        'messageId': 'msg-2',
      });

      expect(result, isNotNull);
      expect(result!.translatedContent, isNull);
      expect(result.sourceLanguage, isNull);
      expect(result.targetLanguage, isNull);
      expect(result.status, TranslationStatus.pending);
    });
  });

  group('TranslationResult.parseList', () {
    test('parses bare list', () {
      final results = TranslationResult.parseList([
        {'messageId': 'm1', 'status': 'translated'},
        {'messageId': 'm2', 'status': 'failed'},
      ]);
      expect(results, hasLength(2));
      expect(results[0].messageId, 'm1');
      expect(results[1].status, TranslationStatus.failed);
    });

    test('parses wrapped response', () {
      final results = TranslationResult.parseList({
        'translations': [
          {'messageId': 'm1', 'translatedContent': 'Bonjour'},
        ],
      });
      expect(results, hasLength(1));
      expect(results[0].translatedContent, 'Bonjour');
    });

    test('skips invalid entries', () {
      final results = TranslationResult.parseList([
        {'messageId': 'valid', 'status': 'translated'},
        {'messageId': ''},
        'not a map',
        {'foo': 'bar'},
      ]);
      expect(results, hasLength(1));
    });

    test('returns empty for null/unknown input', () {
      expect(TranslationResult.parseList(null), isEmpty);
      expect(TranslationResult.parseList('string'), isEmpty);
      expect(TranslationResult.parseList(42), isEmpty);
    });
  });
}

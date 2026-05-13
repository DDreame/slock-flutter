import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';

void main() {
  group('Announcement.fromMap', () {
    test('parses complete announcement from JSON map', () {
      final announcement = Announcement.fromMap({
        'id': 'ann-1',
        'title': 'System Update',
        'body': 'We are performing maintenance.',
        'dismissible': true,
        'createdAt': '2026-05-10T12:00:00Z',
      });

      expect(announcement, isNotNull);
      expect(announcement!.id, 'ann-1');
      expect(announcement.title, 'System Update');
      expect(announcement.body, 'We are performing maintenance.');
      expect(announcement.dismissible, isTrue);
      expect(announcement.createdAt, DateTime.utc(2026, 5, 10, 12));
    });

    test('returns null for missing required fields', () {
      expect(Announcement.fromMap({'title': 'No ID'}), isNull);
      expect(Announcement.fromMap({'id': 'ann-2'}), isNull);
      expect(Announcement.fromMap({}), isNull);
    });

    test('defaults dismissible to true when missing', () {
      final announcement = Announcement.fromMap({
        'id': 'ann-3',
        'title': 'Notice',
      });

      expect(announcement, isNotNull);
      expect(announcement!.dismissible, isTrue);
    });

    test('handles non-dismissible announcement', () {
      final announcement = Announcement.fromMap({
        'id': 'ann-4',
        'title': 'Mandatory',
        'dismissible': false,
      });

      expect(announcement, isNotNull);
      expect(announcement!.dismissible, isFalse);
    });
  });

  group('Announcement.parseList', () {
    test('parses list of announcements from bare list', () {
      final results = Announcement.parseList([
        {'id': 'a1', 'title': 'First'},
        {'id': 'a2', 'title': 'Second', 'body': 'Details'},
      ]);

      expect(results, hasLength(2));
      expect(results[0].id, 'a1');
      expect(results[1].id, 'a2');
      expect(results[1].body, 'Details');
    });

    test('parses from {"announcements": [...]} response', () {
      final results = Announcement.parseList({
        'announcements': [
          {'id': 'b1', 'title': 'Wrapped'},
        ],
      });

      expect(results, hasLength(1));
      expect(results[0].id, 'b1');
    });

    test('skips invalid entries', () {
      final results = Announcement.parseList([
        {'id': 'valid', 'title': 'OK'},
        {'id': '', 'title': 'Bad ID'},
        'not a map',
        {'title': 'Missing ID'},
      ]);

      expect(results, hasLength(1));
      expect(results[0].id, 'valid');
    });

    test('returns empty list for null/unknown input', () {
      expect(Announcement.parseList(null), isEmpty);
      expect(Announcement.parseList('string'), isEmpty);
      expect(Announcement.parseList(42), isEmpty);
    });
  });
}

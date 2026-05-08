import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';

void main() {
  group('LinkMetadata', () {
    test('constructs with required fields', () {
      const meta = LinkMetadata(
        url: 'https://example.com/article',
        title: 'Example Article',
        domain: 'example.com',
      );
      expect(meta.url, 'https://example.com/article');
      expect(meta.title, 'Example Article');
      expect(meta.description, isNull);
      expect(meta.imageUrl, isNull);
      expect(meta.domain, 'example.com');
    });

    test('constructs with all fields', () {
      const meta = LinkMetadata(
        url: 'https://example.com/article',
        title: 'Example Article',
        description: 'A great article about testing.',
        imageUrl: 'https://example.com/image.jpg',
        domain: 'example.com',
      );
      expect(meta.description, 'A great article about testing.');
      expect(meta.imageUrl, 'https://example.com/image.jpg');
    });

    test('isDisplayable is true when title is non-empty', () {
      const meta = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        domain: 'example.com',
      );
      expect(meta.isDisplayable, isTrue);
    });

    test('isDisplayable is false when title is empty', () {
      const meta = LinkMetadata(
        url: 'https://example.com',
        title: '',
        domain: 'example.com',
      );
      expect(meta.isDisplayable, isFalse);
    });

    test('equality compares all fields', () {
      const a = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        description: 'Desc',
        imageUrl: 'https://example.com/img.png',
        domain: 'example.com',
      );
      const b = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        description: 'Desc',
        imageUrl: 'https://example.com/img.png',
        domain: 'example.com',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when fields differ', () {
      const a = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        domain: 'example.com',
      );
      const b = LinkMetadata(
        url: 'https://other.com',
        title: 'Other',
        domain: 'other.com',
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes key fields', () {
      const meta = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        domain: 'example.com',
      );
      expect(meta.toString(), contains('example.com'));
      expect(meta.toString(), contains('Example'));
    });
  });
}

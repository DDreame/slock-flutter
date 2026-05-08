import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

void main() {
  group('SharedContentItem', () {
    test('isAttachment is true for image, video, file', () {
      expect(
        const SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ).isAttachment,
        isTrue,
      );
      expect(
        const SharedContentItem(
          type: SharedContentType.video,
          path: '/tmp/video.mp4',
        ).isAttachment,
        isTrue,
      );
      expect(
        const SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/doc.pdf',
        ).isAttachment,
        isTrue,
      );
    });

    test('isAttachment is false for text, url', () {
      expect(
        const SharedContentItem(
          type: SharedContentType.text,
          path: 'Hello world',
        ).isAttachment,
        isFalse,
      );
      expect(
        const SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ).isAttachment,
        isFalse,
      );
    });

    test('isText is true for text, url', () {
      expect(
        const SharedContentItem(
          type: SharedContentType.text,
          path: 'Hello',
        ).isText,
        isTrue,
      );
      expect(
        const SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ).isText,
        isTrue,
      );
    });

    test('isText is false for image, video, file', () {
      expect(
        const SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ).isText,
        isFalse,
      );
    });

    test('equality works with same values', () {
      const a = SharedContentItem(
        type: SharedContentType.image,
        path: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
      );
      const b = SharedContentItem(
        type: SharedContentType.image,
        path: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality fails with different values', () {
      const a = SharedContentItem(
        type: SharedContentType.image,
        path: '/tmp/a.jpg',
      );
      const b = SharedContentItem(
        type: SharedContentType.image,
        path: '/tmp/b.jpg',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('SharedContent', () {
    test('isEmpty returns true for empty items', () {
      const content = SharedContent(items: []);
      expect(content.isEmpty, isTrue);
      expect(content.isNotEmpty, isFalse);
    });

    test('isNotEmpty returns true for non-empty items', () {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
      ]);
      expect(content.isNotEmpty, isTrue);
      expect(content.isEmpty, isFalse);
    });

    test('textItems filters to text and url types', () {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ),
        SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ),
      ]);
      expect(content.textItems, hasLength(2));
      expect(content.textItems[0].type, SharedContentType.text);
      expect(content.textItems[1].type, SharedContentType.url);
    });

    test('attachmentItems filters to image, video, file types', () {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ),
        SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/doc.pdf',
        ),
      ]);
      expect(content.attachmentItems, hasLength(2));
      expect(content.attachmentItems[0].type, SharedContentType.image);
      expect(content.attachmentItems[1].type, SharedContentType.file);
    });

    test('combinedText joins text items with newlines', () {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'line 1'),
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ),
        SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ),
      ]);
      expect(content.combinedText, 'line 1\nhttps://example.com');
    });

    test('combinedText returns empty string for no text items', () {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
        ),
      ]);
      expect(content.combinedText, '');
    });

    test('equality works with same items', () {
      const a = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
      ]);
      const b = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
      ]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality fails with different items', () {
      const a = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'hello'),
      ]);
      const b = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'world'),
      ]);
      expect(a, isNot(equals(b)));
    });
  });
}

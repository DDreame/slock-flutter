import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

void main() {
  group('MessageAttachment payload normalization', () {
    group('new payload fields (filename/mimeType/thumbnailUrl)', () {
      test('parses new-style payload with filename and mimeType', () {
        final payload = [
          {
            'id': 'att-1',
            'filename': 'screenshot.png',
            'mimeType': 'image/png',
            'thumbnailUrl': 'https://cdn.example.com/thumb/att-1.png',
            'sizeBytes': 204800,
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);
        expect(result!, hasLength(1));

        final att = result.first;
        expect(att.name, 'screenshot.png');
        expect(att.type, 'image/png');
        expect(att.url, 'https://cdn.example.com/thumb/att-1.png');
        expect(att.id, 'att-1');
        expect(att.sizeBytes, 204800);
        expect(att.thumbnailUrl, 'https://cdn.example.com/thumb/att-1.png');
      });

      test('new-style payload without thumbnailUrl yields null url', () {
        final payload = [
          {
            'id': 'att-2',
            'filename': 'report.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 512000,
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);
        final att = result!.first;
        expect(att.name, 'report.pdf');
        expect(att.type, 'application/pdf');
        expect(att.url, isNull);
        expect(att.thumbnailUrl, isNull);
        expect(att.id, 'att-2');
      });
    });

    group('old payload backward compat (name/type/url)', () {
      test('parses old-style payload with name and type', () {
        final payload = [
          {
            'id': 'att-old',
            'name': 'doc.pdf',
            'type': 'application/pdf',
            'url': 'https://old.example.com/doc.pdf',
            'sizeBytes': 1024,
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);

        final att = result!.first;
        expect(att.name, 'doc.pdf');
        expect(att.type, 'application/pdf');
        expect(att.url, 'https://old.example.com/doc.pdf');
        expect(att.id, 'att-old');
        expect(att.sizeBytes, 1024);
        expect(att.thumbnailUrl, isNull);
      });

      test('old-style payload uses url but not thumbnailUrl', () {
        final payload = [
          {
            'name': 'photo.jpg',
            'type': 'image/jpeg',
            'url': 'https://old.example.com/photo.jpg',
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);
        final att = result!.first;
        expect(att.url, 'https://old.example.com/photo.jpg');
        expect(att.thumbnailUrl, isNull);
      });
    });

    group('mixed payload precedence', () {
      test('old fields take priority when both old and new present', () {
        final payload = [
          {
            'id': 'att-mix',
            'name': 'old-name.png',
            'filename': 'new-name.png',
            'type': 'image/png',
            'mimeType': 'image/webp',
            'url': 'https://old.example.com/old.png',
            'thumbnailUrl': 'https://cdn.example.com/new.png',
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);
        final att = result!.first;
        // Old fields take priority for backward compat
        expect(att.name, 'old-name.png');
        expect(att.type, 'image/png');
        expect(att.url, 'https://old.example.com/old.png');
        // thumbnailUrl still captured separately
        expect(att.thumbnailUrl, 'https://cdn.example.com/new.png');
      });
    });

    group('edge cases', () {
      test('drops entry with neither name nor filename', () {
        final payload = [
          {
            'id': 'att-no-name',
            'type': 'image/png',
            'url': 'https://example.com/img.png',
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNull);
      });

      test('drops entry with neither type nor mimeType', () {
        final payload = [
          {
            'id': 'att-no-type',
            'name': 'file.bin',
            'url': 'https://example.com/file.bin',
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNull);
      });

      test('empty list returns null', () {
        final result = parseAttachments([]);
        expect(result, isNull);
      });

      test('null returns null', () {
        final result = parseAttachments(null);
        expect(result, isNull);
      });

      test('multiple items with mixed old/new parse correctly', () {
        final payload = [
          {
            'name': 'old-file.txt',
            'type': 'text/plain',
            'url': 'https://old.example.com/old.txt',
          },
          {
            'id': 'att-new',
            'filename': 'new-file.html',
            'mimeType': 'text/html',
            'thumbnailUrl': 'https://cdn.example.com/preview.html',
          },
        ];

        final result = parseAttachments(payload);
        expect(result, isNotNull);
        expect(result!, hasLength(2));
        expect(result[0].name, 'old-file.txt');
        expect(result[1].name, 'new-file.html');
        expect(result[1].thumbnailUrl, 'https://cdn.example.com/preview.html');
      });
    });
  });

  group('MessageAttachment.thumbnailUrl field', () {
    test('model stores thumbnailUrl', () {
      const att = MessageAttachment(
        name: 'img.png',
        type: 'image/png',
        id: 'att-1',
        thumbnailUrl: 'https://cdn.example.com/thumb.png',
      );
      expect(att.thumbnailUrl, 'https://cdn.example.com/thumb.png');
    });

    test('model equality includes thumbnailUrl', () {
      const att1 = MessageAttachment(
        name: 'img.png',
        type: 'image/png',
        thumbnailUrl: 'https://a.com/1',
      );
      const att2 = MessageAttachment(
        name: 'img.png',
        type: 'image/png',
        thumbnailUrl: 'https://a.com/2',
      );
      expect(att1, isNot(equals(att2)));
    });
  });
}

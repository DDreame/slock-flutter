import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';

import '../../../support/support.dart';

void main() {
  test('avatar upload uses JPEG content type for jpg files (#722)', () async {
    final tempDir = await Directory.systemTemp.createTemp('avatar-upload-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final jpeg = File('${tempDir.path}/avatar.jpg');
    await jpeg.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

    final dioClient = FakeAppDioClient(
      responses: const {
        ('PUT', '/users/me'): {'avatarUrl': 'https://cdn/avatar.jpg'},
      },
    );
    final service = AvatarUploadService.forTesting(appDioClient: dioClient);

    final url = await service.upload(jpeg.path);

    expect(url, 'https://cdn/avatar.jpg');
    final request = dioClient.requests.single;
    expect(request.data, isA<FormData>());
    final formData = request.data! as FormData;
    final upload = formData.files.single.value;
    expect(upload.contentType.toString(), 'image/jpeg');
    expect(upload.filename, 'avatar.jpg');
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// #575: Avatar Upload Service — Stub (Phase A)
//
// Provides the seam providers referenced by Phase A tests.
// Phase B implements the actual image picker and upload logic.
// ---------------------------------------------------------------------------

/// Injectable image picker seam. Phase B replaces with real ImagePicker.
///
/// Returns the file path of the picked image, or null if cancelled.
final imagePickerProvider = Provider<ImagePickerService>((ref) {
  throw UnimplementedError('#575 Phase B: implement image picker provider');
});

/// Injectable avatar upload service seam. Phase B replaces with real
/// multipart upload to PUT /users/me.
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  throw UnimplementedError('#575 Phase B: implement avatar upload service');
});

/// Abstract image picker interface for testability.
abstract class ImagePickerService {
  /// Pick an image from gallery. Returns file path or null if cancelled.
  Future<String?> pickImage();
}

/// Abstract avatar upload service for testability.
abstract class AvatarUploadService {
  /// Upload the image at [filePath] and return the new avatar URL.
  Future<String> upload(String filePath);
}

/// Exception thrown when avatar upload fails.
class AvatarUploadException implements Exception {
  AvatarUploadException(this.message);
  final String message;

  @override
  String toString() => 'AvatarUploadException: $message';
}

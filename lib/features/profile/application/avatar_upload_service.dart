import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:slock_app/core/core.dart';

// ---------------------------------------------------------------------------
// #575: Avatar Upload Service — Phase B
//
// Real implementations of image picker and avatar upload via PUT /users/me.
// ---------------------------------------------------------------------------

/// Injectable image picker seam.
final imagePickerProvider = Provider<ImagePickerService>((ref) {
  return _RealImagePickerService();
});

/// Injectable avatar upload service.
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAvatarUploadService(appDioClient: appDioClient);
});

/// Abstract image picker interface for testability.
abstract class ImagePickerService {
  /// Pick an image from gallery. Returns file path or null if cancelled.
  Future<String?> pickImage();
}

/// Abstract avatar upload service for testability.
abstract class AvatarUploadService {
  factory AvatarUploadService.forTesting({
    required AppDioClient appDioClient,
  }) = _ApiAvatarUploadService;

  /// Upload the image at [filePath] and return the new avatar URL.
  Future<String> upload(String filePath);
}

/// Exception thrown when avatar upload fails.
class AvatarUploadException implements Exception {
  AvatarUploadException(this.message, {this.failure, required this.code});
  final String message;
  final AppFailure? failure;
  final AvatarUploadErrorCode code;

  @override
  String toString() => 'AvatarUploadException: $message';
}

/// Error codes for [AvatarUploadException], enabling localized messages
/// at the presentation layer without a [BuildContext] dependency in the service.
enum AvatarUploadErrorCode {
  invalidResponse,
  uploadFailed,
  uploadFailedRetry,
}

// ---------------------------------------------------------------------------
// Real implementations
// ---------------------------------------------------------------------------

class _RealImagePickerService implements ImagePickerService {
  final _picker = ImagePicker();

  @override
  Future<String?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    return file?.path;
  }
}

const _uploadPath = '/users/me';

String _mimeTypeForFile(String filePath) {
  switch (p.extension(filePath).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.png':
    default:
      return 'image/png';
  }
}

class _ApiAvatarUploadService implements AvatarUploadService {
  const _ApiAvatarUploadService({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<String> upload(String filePath) async {
    try {
      final formData = FormData()
        ..files.add(
          MapEntry(
            'avatar',
            await MultipartFile.fromFile(
              filePath,
              filename: 'avatar${p.extension(filePath)}',
              contentType: DioMediaType.parse(_mimeTypeForFile(filePath)),
            ),
          ),
        );

      final response = await _appDioClient.request<Object?>(
        _uploadPath,
        method: 'PUT',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 1),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final avatarUrl = data['avatarUrl'] as String?;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          return avatarUrl;
        }
      }

      throw AvatarUploadException(
        'Invalid response from server.',
        code: AvatarUploadErrorCode.invalidResponse,
      );
    } on AvatarUploadException {
      rethrow;
    } on AppFailure catch (failure) {
      throw AvatarUploadException(
        'Upload failed.',
        failure: failure,
        code: AvatarUploadErrorCode.uploadFailed,
      );
    } catch (error) {
      throw AvatarUploadException(
        'Upload failed. Please try again.',
        code: AvatarUploadErrorCode.uploadFailedRetry,
      );
    }
  }
}

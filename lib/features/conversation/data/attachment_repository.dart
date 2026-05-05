import 'package:slock_app/core/core.dart';

/// Contract for attachment-specific API operations.
///
/// Provides signed download URLs and HTML preview sandbox URLs
/// for message attachments.
abstract class AttachmentRepository {
  /// Fetch a signed download URL for an attachment.
  ///
  /// Calls `GET /attachments/{attachmentId}/url`.
  /// Returns the signed URL string (short-lived, cached by the server).
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  });

  /// Fetch a sandbox HTML preview URL for an attachment.
  ///
  /// Calls `GET /attachments/{attachmentId}/html-preview-url`.
  /// Returns a sandbox URL safe for rendering in external browser
  /// (no app tokens injected).
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  });
}

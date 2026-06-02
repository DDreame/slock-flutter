import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';

/// Resolves signed download URLs for attachments.
///
/// Thin application-layer wrapper around [AttachmentRepository.getSignedUrl].
/// Presentation code should use this instead of importing the repository
/// provider directly.
final attachmentSignedUrlProvider = Provider<
    Future<String> Function(ServerScopeId serverId,
        {required String attachmentId})>(
  (ref) {
    return (ServerScopeId serverId, {required String attachmentId}) =>
        ref.read(attachmentRepositoryProvider).getSignedUrl(
              serverId,
              attachmentId: attachmentId,
            );
  },
);

/// Resolves sandbox HTML preview URLs for attachments.
///
/// Thin application-layer wrapper around [AttachmentRepository.getHtmlPreviewUrl].
final attachmentHtmlPreviewUrlProvider = Provider<
    Future<String> Function(ServerScopeId serverId,
        {required String attachmentId})>(
  (ref) {
    return (ServerScopeId serverId, {required String attachmentId}) =>
        ref.read(attachmentRepositoryProvider).getHtmlPreviewUrl(
              serverId,
              attachmentId: attachmentId,
            );
  },
);

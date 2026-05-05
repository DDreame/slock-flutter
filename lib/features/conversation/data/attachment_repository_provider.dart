import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _attachmentsPath = '/attachments';
const _diagTag = 'attachment-preview';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final diagnostics = ref.watch(diagnosticsCollectorProvider);
  return _ApiAttachmentRepository(
    appDioClient: appDioClient,
    diagnostics: diagnostics,
  );
});

class _ApiAttachmentRepository implements AttachmentRepository {
  _ApiAttachmentRepository({
    required AppDioClient appDioClient,
    required DiagnosticsCollector diagnostics,
  })  : _appDioClient = appDioClient,
        _diagnostics = diagnostics;

  final AppDioClient _appDioClient;
  final DiagnosticsCollector _diagnostics;

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_attachmentsPath/$attachmentId/url',
        options: _serverScopedOptions(serverId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          _diagnostics.info(
            _diagTag,
            'source=signedUrl, attachmentId=$attachmentId',
          );
          return url;
        }
      }
      throw const SerializationFailure(
        message: 'Invalid signed URL response payload.',
      );
    } on AppFailure catch (e) {
      _diagnostics.error(
        _diagTag,
        'source=signedUrl, attachmentId=$attachmentId, '
        'failureType=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_attachmentsPath/$attachmentId/html-preview-url',
        options: _serverScopedOptions(serverId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          _diagnostics.info(
            _diagTag,
            'source=htmlPreview, attachmentId=$attachmentId',
          );
          return url;
        }
      }
      throw const SerializationFailure(
        message: 'Invalid HTML preview URL response payload.',
      );
    } on AppFailure catch (e) {
      _diagnostics.error(
        _diagTag,
        'source=htmlPreview, attachmentId=$attachmentId, '
        'failureType=${e.runtimeType}',
      );
      rethrow;
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.routeParam});
  }
}

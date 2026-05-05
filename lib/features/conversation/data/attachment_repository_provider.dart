import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _attachmentsPath = '/attachments';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiAttachmentRepository(appDioClient: appDioClient);
});

class _ApiAttachmentRepository implements AttachmentRepository {
  _ApiAttachmentRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    developer.log(
      'getSignedUrl: id=$attachmentId',
      name: 'AttachmentRepository',
    );
    try {
      final response = await _appDioClient.get<Object?>(
        '$_attachmentsPath/$attachmentId/url',
        options: _serverScopedOptions(serverId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      throw const SerializationFailure(
        message: 'Invalid signed URL response payload.',
      );
    } on AppFailure {
      rethrow;
    }
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    developer.log(
      'getHtmlPreviewUrl: id=$attachmentId',
      name: 'AttachmentRepository',
    );
    try {
      final response = await _appDioClient.get<Object?>(
        '$_attachmentsPath/$attachmentId/html-preview-url',
        options: _serverScopedOptions(serverId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      throw const SerializationFailure(
        message: 'Invalid HTML preview URL response payload.',
      );
    } on AppFailure {
      rethrow;
    }
  }

  Options _serverScopedOptions(ServerScopeId serverId) {
    return Options(headers: {_serverHeaderName: serverId.routeParam});
  }
}

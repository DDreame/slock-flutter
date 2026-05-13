import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/channel_files_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _channelsPath = '/channels';

final channelFilesRepositoryProvider = Provider<ChannelFilesRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiChannelFilesRepository(appDioClient: appDioClient);
});

class _ApiChannelFilesRepository implements ChannelFilesRepository {
  const _ApiChannelFilesRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<List<MessageAttachment>> listFiles(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_channelsPath/$channelId/files',
        options: Options(headers: {_serverHeaderName: serverId.value}),
      );
      return _parseFileList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load channel files.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  /// Defensive parsing: try `data['files']`, then `data['attachments']`,
  /// then bare list.
  List<MessageAttachment> _parseFileList(Object? data) {
    if (data is List) {
      return parseAttachments(data) ?? const [];
    }
    if (data is Map<String, dynamic>) {
      final files = data['files'];
      if (files is List) return parseAttachments(files) ?? const [];
      final attachments = data['attachments'];
      if (attachments is List) {
        return parseAttachments(attachments) ?? const [];
      }
    }
    return const [];
  }
}

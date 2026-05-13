import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

const _serverHeaderName = 'X-Server-Id';
const _translationSettingsPath = '/translation/settings';
const _translationBatchPath = '/message-translations:batch';

/// Repository for translation settings and batch message translation.
abstract class TranslationRepository {
  /// Fetches the current server-level translation settings.
  Future<TranslationSettings> getSettings(ServerScopeId serverId);

  /// Updates the server-level translation settings.
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  );

  /// Translates a batch of messages.
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  });
}

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiTranslationRepository(appDioClient: appDioClient);
});

class _ApiTranslationRepository implements TranslationRepository {
  const _ApiTranslationRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  Options _serverOptions(ServerScopeId serverId) =>
      Options(headers: {_serverHeaderName: serverId.value});

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        _translationSettingsPath,
        options: _serverOptions(serverId),
      );
      if (response.data is Map<String, dynamic>) {
        return TranslationSettings.fromMap(
            response.data! as Map<String, dynamic>);
      }
      return const TranslationSettings();
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load translation settings.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings settings,
  ) async {
    try {
      final response = await _appDioClient.patch<Object?>(
        _translationSettingsPath,
        data: settings.toMap(),
        options: _serverOptions(serverId),
      );
      if (response.data is Map<String, dynamic>) {
        return TranslationSettings.fromMap(
            response.data! as Map<String, dynamic>);
      }
      return settings;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update translation settings.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    if (messageIds.isEmpty) return const [];
    try {
      final response = await _appDioClient.post<Object?>(
        _translationBatchPath,
        data: {
          'messageIds': messageIds,
          'targetLanguage': targetLanguage,
        },
        options: _serverOptions(serverId),
      );
      return TranslationResult.parseList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to translate messages.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

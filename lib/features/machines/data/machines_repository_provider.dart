import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';

const _serversPath = '/servers';
const _serverHeaderName = 'X-Server-Id';

final machinesRepositoryProvider = Provider<MachinesRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  final serverId = ref.watch(currentMachinesServerIdProvider);
  return _ApiMachinesRepository(appDioClient: appDioClient, serverId: serverId);
});

final currentMachinesServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentMachinesServerIdProvider must be overridden in a ProviderScope',
  );
});

class _ApiMachinesRepository implements MachinesRepository {
  const _ApiMachinesRepository({
    required AppDioClient appDioClient,
    required ServerScopeId serverId,
  }) : _appDioClient = appDioClient,
       _serverId = serverId;

  final AppDioClient _appDioClient;
  final ServerScopeId _serverId;

  String get _machinesPath => '$_serversPath/${_serverId.routeParam}/machines';

  Options get _serverOptions =>
      Options(headers: {_serverHeaderName: _serverId.value});

  @override
  Future<MachinesSnapshot> loadMachines() async {
    try {
      final response = await _appDioClient.get<Object?>(
        _machinesPath,
        options: _serverOptions,
      );
      return parseMachinesSnapshot(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load machines.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async {
    try {
      final response = await _appDioClient.post<Object?>(
        _machinesPath,
        data: {'name': name},
        options: _serverOptions,
      );
      return parseRegisterMachineResult(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to register machine.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> renameMachine(String machineId, {required String name}) async {
    try {
      await _appDioClient.request<Object?>(
        '$_machinesPath/$machineId',
        method: 'PATCH',
        data: {'name': name},
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to rename machine.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<String> rotateMachineApiKey(String machineId) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '$_machinesPath/$machineId/rotate-key',
        options: _serverOptions,
      );
      return readApiKeyFromPayload(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to rotate machine API key.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteMachine(String machineId) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_machinesPath/$machineId',
        options: _serverOptions,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete machine.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

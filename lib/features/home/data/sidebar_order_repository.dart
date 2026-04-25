import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';

abstract class SidebarOrderRepository {
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId);

  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  });
}

final sidebarOrderRepositoryProvider = Provider<SidebarOrderRepository>((ref) {
  return BaselineSidebarOrderRepository(
    appDioClient: ref.watch(appDioClientProvider),
  );
});

class BaselineSidebarOrderRepository implements SidebarOrderRepository {
  BaselineSidebarOrderRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '/servers/${serverId.routeParam}/sidebar-order',
      );
      return _parseSidebarOrder(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load sidebar order.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    try {
      await _appDioClient.request<void>(
        '/servers/${serverId.routeParam}/sidebar-order',
        method: 'PATCH',
        data: patch,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update sidebar order.',
        causeType: error.runtimeType.toString(),
      );
    }
  }
}

SidebarOrder _parseSidebarOrder(Object? payload) {
  if (payload is! Map<String, dynamic>) {
    return const SidebarOrder();
  }
  return SidebarOrder(
    channelOrder: _parseStringList(payload['channelOrder']),
    dmOrder: _parseStringList(payload['dmOrder']),
    pinnedChannelIds: _parseStringList(payload['pinnedChannelIds']),
    pinnedOrder: _parseStringList(payload['pinnedOrder']),
    hiddenDmIds: _parseStringList(payload['hiddenDmIds']),
  );
}

List<String> _parseStringList(Object? payload) {
  if (payload is! List) return const [];
  return payload.whereType<String>().toList(growable: false);
}

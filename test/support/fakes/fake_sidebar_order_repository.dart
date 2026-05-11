import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

/// Shared fake [SidebarOrderRepository] for tests.
///
/// By default returns an empty [SidebarOrder].
/// Supports failure injection and call tracking.
class FakeSidebarOrderRepository implements SidebarOrderRepository {
  FakeSidebarOrderRepository({
    this.sidebarOrder = const SidebarOrder(),
    this.loadFailure,
    this.updateFailure,
  });

  SidebarOrder sidebarOrder;
  AppFailure? loadFailure;
  AppFailure? updateFailure;

  int loadCalls = 0;
  int patchCalls = 0;
  final List<Map<String, Object>> patches = [];

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    loadCalls++;
    if (loadFailure != null) throw loadFailure!;
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    patchCalls++;
    patches.add(patch);
    if (updateFailure != null) throw updateFailure!;
  }
}

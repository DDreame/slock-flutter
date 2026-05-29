import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/unread_summary_repository.dart';

const _unreadSummaryPath = '/servers/unread-summary';

final unreadSummaryRepositoryProvider =
    Provider<UnreadSummaryRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return BaselineUnreadSummaryRepository(
    loadUnreadSummary: () => _fetchUnreadSummary(appDioClient: appDioClient),
  );
});

/// Function-injection implementation matching existing repository patterns.
class BaselineUnreadSummaryRepository implements UnreadSummaryRepository {
  BaselineUnreadSummaryRepository({
    required Future<List<UnreadSummaryEntry>> Function() loadUnreadSummary,
  }) : _loadUnreadSummary = loadUnreadSummary;

  final Future<List<UnreadSummaryEntry>> Function() _loadUnreadSummary;

  @override
  Future<List<UnreadSummaryEntry>> loadUnreadSummary() => _loadUnreadSummary();
}

Future<List<UnreadSummaryEntry>> _fetchUnreadSummary({
  required AppDioClient appDioClient,
}) async {
  final response = await appDioClient.get<Object?>(_unreadSummaryPath);
  return _parseUnreadSummary(response.data);
}

List<UnreadSummaryEntry> _parseUnreadSummary(Object? payload) {
  if (payload is! List) {
    throw SerializationFailure(
      message: 'Malformed unread-summary payload: expected a list.',
      causeType: _describeType(payload),
    );
  }

  final result = <UnreadSummaryEntry>[];
  for (var i = 0; i < payload.length; i++) {
    final item = payload[i];
    if (item is! Map) continue;
    final map =
        item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

    final serverId = map['serverId'];
    if (serverId is! String || serverId.isEmpty) continue;

    final rawCount = map['unreadCount'];
    if (rawCount is! num || !rawCount.isFinite) continue;

    // Floor + clamp to 0 (matching web: Math.max(0, Math.floor(ke))).
    final count = rawCount.floor();
    result.add(UnreadSummaryEntry(
        serverId: serverId, unreadCount: count < 0 ? 0 : count));
  }
  return result;
}

String _describeType(Object? value) => value?.runtimeType.toString() ?? 'Null';

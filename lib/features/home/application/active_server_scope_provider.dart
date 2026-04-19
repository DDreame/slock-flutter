import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';

const _defaultActiveServerScopeId = ServerScopeId('server-1');

final activeServerScopeIdProvider = Provider<ServerScopeId>(
  (ref) => _defaultActiveServerScopeId,
);

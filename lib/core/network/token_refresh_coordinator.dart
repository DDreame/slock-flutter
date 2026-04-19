import 'package:slock_app/core/network/auth_token_provider.dart';

class TokenRefreshCoordinator {
  TokenRefreshCoordinator({required RefreshAuthToken refreshToken})
    : _refreshToken = refreshToken;

  final RefreshAuthToken _refreshToken;

  Future<String?>? _inFlightRefresh;

  Future<String?> refreshToken() {
    final activeRefresh = _inFlightRefresh;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final nextRefresh = Future<String?>.sync(_refreshToken);
    _inFlightRefresh = nextRefresh;
    nextRefresh.whenComplete(() {
      if (identical(_inFlightRefresh, nextRefresh)) {
        _inFlightRefresh = null;
      }
    });
    return nextRefresh;
  }
}

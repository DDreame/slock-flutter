import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@immutable
class SessionState {
  final AuthStatus status;
  final String? userId;
  final String? displayName;
  final String? token;

  const SessionState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.displayName,
    this.token,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  SessionState copyWith({
    AuthStatus? status,
    String? userId,
    String? displayName,
    String? token,
    bool clearUserId = false,
    bool clearDisplayName = false,
    bool clearToken = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      userId: clearUserId ? null : (userId ?? this.userId),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      token: clearToken ? null : (token ?? this.token),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          userId == other.userId &&
          displayName == other.displayName &&
          token == other.token;

  @override
  int get hashCode => Object.hash(status, userId, displayName, token);
}

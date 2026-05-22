import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@immutable
class SessionState {
  final AuthStatus status;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? token;
  final bool? emailVerified;

  const SessionState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.token,
    this.emailVerified,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  SessionState copyWith({
    AuthStatus? status,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? token,
    bool? emailVerified,
    bool clearUserId = false,
    bool clearDisplayName = false,
    bool clearAvatarUrl = false,
    bool clearBio = false,
    bool clearToken = false,
    bool clearEmailVerified = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      userId: clearUserId ? null : (userId ?? this.userId),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      bio: clearBio ? null : (bio ?? this.bio),
      token: clearToken ? null : (token ?? this.token),
      emailVerified:
          clearEmailVerified ? null : (emailVerified ?? this.emailVerified),
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
          avatarUrl == other.avatarUrl &&
          bio == other.bio &&
          token == other.token &&
          emailVerified == other.emailVerified;

  @override
  int get hashCode => Object.hash(
        status,
        userId,
        displayName,
        avatarUrl,
        bio,
        token,
        emailVerified,
      );
}

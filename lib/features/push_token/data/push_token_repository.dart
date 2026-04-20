abstract class PushTokenRepository {
  Future<void> registerToken({
    required String token,
    required String platform,
  });

  Future<void> deregisterToken({
    required String token,
    String? authToken,
  });
}

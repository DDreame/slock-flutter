import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository.dart';
import 'package:slock_app/features/servers/data/onboarding_settings_repository_provider.dart';

void main() {
  group('onboardingSettingsRepositoryProvider', () {
    test('getSettings sends GET to correct path and parses response', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/srv-1/onboarding-settings'): {
            'setupModalReminderOptOut': true,
            'onboardingReminderOptOut': false,
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(onboardingSettingsRepositoryProvider);
      final settings = await repo.getSettings(const ServerScopeId('srv-1'));

      expect(settings.setupModalReminderOptOut, isTrue);
      expect(settings.onboardingReminderOptOut, isFalse);
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path,
          '/servers/srv-1/onboarding-settings');
    });

    test('getSettings treats missing booleans as false', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/srv-1/onboarding-settings'): <String, dynamic>{},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(onboardingSettingsRepositoryProvider);
      final settings = await repo.getSettings(const ServerScopeId('srv-1'));

      expect(settings.setupModalReminderOptOut, isFalse);
      expect(settings.onboardingReminderOptOut, isFalse);
    });

    test('updateSettings sends PATCH with correct body and parses response',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/servers/srv-2/onboarding-settings'): {
            'setupModalReminderOptOut': true,
            'onboardingReminderOptOut': false,
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(onboardingSettingsRepositoryProvider);
      final result = await repo.updateSettings(
        const ServerScopeId('srv-2'),
        setupModalReminderOptOut: true,
      );

      expect(result.setupModalReminderOptOut, isTrue);
      expect(appDioClient.requests.single.method, 'PATCH');
      expect(appDioClient.requests.single.path,
          '/servers/srv-2/onboarding-settings');
      expect(appDioClient.requests.single.data, {
        'setupModalReminderOptOut': true,
      });
    });

    test('getSettings throws on non-map response', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/srv-1/onboarding-settings'): 'invalid',
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(onboardingSettingsRepositoryProvider);
      expect(
        () => repo.getSettings(const ServerScopeId('srv-1')),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('OnboardingSettings model', () {
    test('equality', () {
      const a = OnboardingSettings(
        setupModalReminderOptOut: true,
        onboardingReminderOptOut: false,
      );
      const b = OnboardingSettings(
        setupModalReminderOptOut: true,
        onboardingReminderOptOut: false,
      );
      const c = OnboardingSettings(
        setupModalReminderOptOut: false,
        onboardingReminderOptOut: false,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith', () {
      const original = OnboardingSettings(
        setupModalReminderOptOut: false,
        onboardingReminderOptOut: true,
      );
      final updated = original.copyWith(setupModalReminderOptOut: true);

      expect(updated.setupModalReminderOptOut, isTrue);
      expect(updated.onboardingReminderOptOut, isTrue);
    });
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<(String, String), Object?> responses = const {}})
      : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    requests.add(_CapturedRequest(method: method, path: path, data: data));

    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path, method: method),
      data: _responses[key] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.data,
  });

  final String method;
  final String path;
  final Object? data;
}

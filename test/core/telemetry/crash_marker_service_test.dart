import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({required String key}) async => store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    store.remove(key);
  }
}

void main() {
  late _FakeSecureStorage fakeStorage;
  late CrashMarkerService service;

  setUp(() {
    fakeStorage = _FakeSecureStorage();
    service = CrashMarkerService(storage: fakeStorage);
  });

  group('CrashMarkerService', () {
    test('hasCrashMarker returns false when no marker exists', () async {
      expect(await service.hasCrashMarker(), isFalse);
    });

    test('hasCrashMarker returns true after markCrash', () async {
      await service.markCrash();
      expect(await service.hasCrashMarker(), isTrue);
    });

    test('markCrash writes one atomic crash_marker payload', () async {
      await service.markCrash();

      final raw = fakeStorage.store['crash_marker'];
      expect(raw, isNotNull);
      expect(fakeStorage.store.containsKey('crash_marker_timestamp'), isFalse);

      final payload = jsonDecode(raw!) as Map<String, Object?>;
      expect(payload['crashed'], isTrue);
      expect(payload['timestamp'], isA<String>());
      expect(DateTime.tryParse(payload['timestamp']! as String), isNotNull);
    });

    test('getCrashTimestamp returns null when no marker exists', () async {
      expect(await service.getCrashTimestamp(), isNull);
    });

    test('getCrashTimestamp returns a DateTime after markCrash', () async {
      await service.markCrash();
      final timestamp = await service.getCrashTimestamp();
      expect(timestamp, isNotNull);
      expect(timestamp, isA<DateTime>());
    });

    test('partial marker state is ignored', () async {
      fakeStorage.store['crash_marker'] = jsonEncode(<String, Object?>{
        'crashed': true,
      });

      expect(await service.hasCrashMarker(), isFalse);
      expect(await service.getCrashTimestamp(), isNull);

      fakeStorage.store['crash_marker_timestamp'] =
          DateTime.now().toIso8601String();

      expect(await service.hasCrashMarker(), isFalse);
      expect(await service.getCrashTimestamp(), isNull);
    });

    test('clearCrashMarker removes marker and timestamp', () async {
      await service.markCrash();
      expect(await service.hasCrashMarker(), isTrue);
      expect(await service.getCrashTimestamp(), isNotNull);

      await service.clearCrashMarker();

      expect(await service.hasCrashMarker(), isFalse);
      expect(await service.getCrashTimestamp(), isNull);
      expect(fakeStorage.store.containsKey('crash_marker'), isFalse);
      expect(
        fakeStorage.store.containsKey('crash_marker_timestamp'),
        isFalse,
      );
    });

    test('multiple markCrash calls update timestamp', () async {
      await service.markCrash();
      final first = await service.getCrashTimestamp();

      // Small delay to ensure timestamps differ.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.markCrash();
      final second = await service.getCrashTimestamp();

      expect(first, isNotNull);
      expect(second, isNotNull);
      // The second timestamp should be at or after the first.
      expect(second!.isAfter(first!) || second == first, isTrue);
    });
  });

  group('crashMarkerServiceProvider', () {
    test('resolves via secureStorageProvider', () {
      final fakeStorage = _FakeSecureStorage();
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(crashMarkerServiceProvider);
      expect(service, isA<CrashMarkerService>());
    });
  });
}

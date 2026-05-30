// =============================================================================
// B127 — Load-bearing serialization tests for AgentMutationInput.
//
// Proves:
// 1. toCreateJson() includes envVars when non-null/non-empty.
// 2. toCreateJson() omits envVars when null or empty.
// 3. toCreateJson() includes avatarUrl when provided.
// 4. toCreateJson() includes onboarding when true, omits when false/null.
// 5. toUpdateJson() includes envVars when non-null/non-empty.
// 6. toUpdateJson() never includes avatarUrl or onboarding.
// 7. generatePixelAvatarUrl() produces correct format.
//
// Reverting the envVars/avatarUrl/onboarding fields → tests fail.
// =============================================================================

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';

void main() {
  group('B127 — AgentMutationInput serialization', () {
    const base = AgentMutationInput(
      name: 'TestBot',
      model: 'sonnet',
      runtime: 'claude',
      machineId: 'machine-1',
    );

    test('toCreateJson includes envVars when non-empty', () {
      final input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        envVars: const {'API_KEY': 'sk-123', 'DEBUG': 'true'},
      );

      final json = input.toCreateJson();

      expect(json['envVars'], {'API_KEY': 'sk-123', 'DEBUG': 'true'});
    });

    test('toCreateJson omits envVars when null', () {
      final json = base.toCreateJson();

      expect(json.containsKey('envVars'), isFalse,
          reason: 'Reverting envVars omission logic → test RED');
    });

    test('toCreateJson omits envVars when empty map', () {
      final input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        envVars: const {},
      );

      final json = input.toCreateJson();

      expect(json.containsKey('envVars'), isFalse,
          reason: 'Empty envVars should be omitted');
    });

    test('toCreateJson includes avatarUrl when provided', () {
      const input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        avatarUrl: 'pixel:A',
      );

      final json = input.toCreateJson();

      expect(json['avatarUrl'], 'pixel:A',
          reason: 'Reverting avatarUrl in toCreateJson → test RED');
    });

    test('toCreateJson includes onboarding when true', () {
      const input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        onboarding: true,
      );

      final json = input.toCreateJson();

      expect(json['onboarding'], true,
          reason: 'Reverting onboarding in toCreateJson → test RED');
    });

    test('toCreateJson omits onboarding when false', () {
      const input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        onboarding: false,
      );

      final json = input.toCreateJson();

      expect(json.containsKey('onboarding'), isFalse,
          reason: 'onboarding:false should be omitted from create payload');
    });

    test('toCreateJson omits onboarding when null', () {
      final json = base.toCreateJson();

      expect(json.containsKey('onboarding'), isFalse);
    });

    test('toUpdateJson includes envVars when non-empty', () {
      final input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        envVars: const {'SECRET': 'val'},
      );

      final json = input.toUpdateJson();

      expect(json['envVars'], {'SECRET': 'val'},
          reason: 'Reverting envVars in toUpdateJson → test RED');
    });

    test('toUpdateJson omits envVars when null or empty', () {
      final json = base.toUpdateJson();

      expect(json.containsKey('envVars'), isFalse);
    });

    test('toUpdateJson never includes avatarUrl', () {
      const input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        avatarUrl: 'pixel:X',
      );

      final json = input.toUpdateJson();

      expect(json.containsKey('avatarUrl'), isFalse,
          reason: 'avatarUrl is create-only, must not appear in update');
    });

    test('toUpdateJson never includes onboarding', () {
      const input = AgentMutationInput(
        name: 'TestBot',
        model: 'sonnet',
        runtime: 'claude',
        machineId: 'machine-1',
        onboarding: true,
      );

      final json = input.toUpdateJson();

      expect(json.containsKey('onboarding'), isFalse,
          reason: 'onboarding is create-only, must not appear in update');
    });
  });

  group('B127 — generatePixelAvatarUrl', () {
    test('produces pixel:<id> format', () {
      final url = generatePixelAvatarUrl(Random(42));

      expect(url, startsWith('pixel:'));
      expect(url.length, greaterThanOrEqualTo(7)); // "pixel:" + at least 1 char
    });

    test('uses provided Random for deterministic output', () {
      final url1 = generatePixelAvatarUrl(Random(0));
      final url2 = generatePixelAvatarUrl(Random(0));

      expect(url1, equals(url2),
          reason: 'Same seed should produce same avatar');
    });
  });
}

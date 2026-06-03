import 'dart:math';

import 'package:flutter/foundation.dart';

/// Characters used to generate random pixel avatar IDs.
const _pixelAvatarIds = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
];

/// Generates a random pixel avatar URL for agent creation.
String generatePixelAvatarUrl([Random? random]) {
  final rng = random ?? Random();
  final id = _pixelAvatarIds[rng.nextInt(_pixelAvatarIds.length)];
  return 'pixel:$id';
}

@immutable
class AgentMutationInput {
  const AgentMutationInput({
    required this.name,
    required this.model,
    required this.runtime,
    required this.machineId,
    this.description,
    this.reasoningEffort,
    this.envVars,
    this.avatarUrl,
    this.onboarding,
  });

  final String name;
  final String? description;
  final String model;
  final String runtime;
  final String? reasoningEffort;
  final String machineId;
  final Map<String, String>? envVars;
  final String? avatarUrl;
  final bool? onboarding;

  Map<String, Object?> toCreateJson() {
    return {
      'name': name,
      'description': _normalizedOptional(description),
      'model': model,
      'runtime': runtime,
      'reasoningEffort': _normalizedOptional(reasoningEffort),
      'machineId': machineId,
      if (envVars != null && envVars!.isNotEmpty) 'envVars': envVars,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (onboarding == true) 'onboarding': true,
    }..removeWhere((_, value) => value == null);
  }

  Map<String, Object?> toUpdateJson() {
    return {
      'name': name,
      'description': _normalizedOptional(description),
      'model': model,
      'runtime': runtime,
      'reasoningEffort': _normalizedOptional(reasoningEffort),
      'machineId': machineId,
      if (envVars != null && envVars!.isNotEmpty) 'envVars': envVars,
    };
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

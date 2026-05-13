import 'package:flutter/foundation.dart';

/// Translation mode for the server.
enum TranslationMode {
  /// Automatically translate messages when entering a conversation.
  auto,

  /// Only translate when the user explicitly requests it.
  manual,

  /// Translation is disabled.
  off;

  static TranslationMode fromString(String? value) {
    return switch (value) {
      'auto' => TranslationMode.auto,
      'manual' => TranslationMode.manual,
      'off' => TranslationMode.off,
      _ => TranslationMode.off,
    };
  }
}

/// Server-level translation settings.
@immutable
class TranslationSettings {
  const TranslationSettings({
    this.preferredLanguage = 'en',
    this.preferredTimezone,
    this.mode = TranslationMode.off,
  });

  final String preferredLanguage;
  final String? preferredTimezone;
  final TranslationMode mode;

  /// Parses [TranslationSettings] from a JSON map.
  static TranslationSettings fromMap(Map<String, dynamic> map) {
    return TranslationSettings(
      preferredLanguage: map['preferredLanguage'] is String
          ? map['preferredLanguage'] as String
          : 'en',
      preferredTimezone: map['preferredTimezone'] is String
          ? map['preferredTimezone'] as String
          : null,
      mode: TranslationMode.fromString(
        map['mode'] is String ? map['mode'] as String : null,
      ),
    );
  }

  /// Converts to a JSON-compatible map for API calls.
  Map<String, dynamic> toMap() {
    return {
      'preferredLanguage': preferredLanguage,
      if (preferredTimezone != null) 'preferredTimezone': preferredTimezone,
      'mode': mode.name,
    };
  }

  TranslationSettings copyWith({
    String? preferredLanguage,
    String? preferredTimezone,
    bool clearTimezone = false,
    TranslationMode? mode,
  }) {
    return TranslationSettings(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredTimezone:
          clearTimezone ? null : (preferredTimezone ?? this.preferredTimezone),
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TranslationSettings &&
            runtimeType == other.runtimeType &&
            preferredLanguage == other.preferredLanguage &&
            preferredTimezone == other.preferredTimezone &&
            mode == other.mode;
  }

  @override
  int get hashCode => Object.hash(preferredLanguage, preferredTimezone, mode);
}

/// Status of a single message translation.
enum TranslationStatus {
  pending,
  translated,
  failed;

  static TranslationStatus fromString(String? value) {
    return switch (value) {
      'pending' => TranslationStatus.pending,
      'translated' => TranslationStatus.translated,
      'failed' => TranslationStatus.failed,
      _ => TranslationStatus.pending,
    };
  }
}

/// Result of translating a single message.
@immutable
class TranslationResult {
  const TranslationResult({
    required this.messageId,
    this.translatedContent,
    this.sourceLanguage,
    this.targetLanguage,
    this.status = TranslationStatus.pending,
  });

  final String messageId;
  final String? translatedContent;
  final String? sourceLanguage;
  final String? targetLanguage;
  final TranslationStatus status;

  /// Parses a [TranslationResult] from a JSON map. Returns null if
  /// required fields are missing.
  static TranslationResult? fromMap(Map<String, dynamic> map) {
    final messageId = map['messageId'];
    if (messageId is! String || messageId.isEmpty) return null;
    return TranslationResult(
      messageId: messageId,
      translatedContent: map['translatedContent'] is String
          ? map['translatedContent'] as String
          : null,
      sourceLanguage: map['sourceLanguage'] is String
          ? map['sourceLanguage'] as String
          : null,
      targetLanguage: map['targetLanguage'] is String
          ? map['targetLanguage'] as String
          : null,
      status: TranslationStatus.fromString(
        map['status'] is String ? map['status'] as String : null,
      ),
    );
  }

  /// Parses a list of translation results from API response.
  /// Tries `data['translations']`, then bare list.
  static List<TranslationResult> parseList(Object? data) {
    List? rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      final translations = data['translations'];
      if (translations is List) rawList = translations;
    }
    if (rawList == null) return const [];

    final results = <TranslationResult>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      final result = TranslationResult.fromMap(map);
      if (result != null) results.add(result);
    }
    return results;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TranslationResult &&
            runtimeType == other.runtimeType &&
            messageId == other.messageId;
  }

  @override
  int get hashCode => messageId.hashCode;
}

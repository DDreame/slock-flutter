import 'package:flutter/foundation.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/features/settings/data/base_url_settings.dart';

@immutable
class BaseUrlSettingsState {
  const BaseUrlSettingsState({
    this.settings = const BaseUrlSettings(),
    this.apiTestResult,
    this.realtimeTestResult,
    this.isTesting = false,
    this.isDirty = false,
  });

  final BaseUrlSettings settings;
  final ConnectionTestResult? apiTestResult;
  final ConnectionTestResult? realtimeTestResult;
  final bool isTesting;

  /// True when the in-memory values differ from the last-saved values.
  final bool isDirty;

  BaseUrlSettingsState copyWith({
    BaseUrlSettings? settings,
    ConnectionTestResult? apiTestResult,
    ConnectionTestResult? realtimeTestResult,
    bool? isTesting,
    bool? isDirty,
    bool clearApiTest = false,
    bool clearRealtimeTest = false,
  }) {
    return BaseUrlSettingsState(
      settings: settings ?? this.settings,
      apiTestResult:
          clearApiTest ? null : (apiTestResult ?? this.apiTestResult),
      realtimeTestResult: clearRealtimeTest
          ? null
          : (realtimeTestResult ?? this.realtimeTestResult),
      isTesting: isTesting ?? this.isTesting,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseUrlSettingsState &&
          runtimeType == other.runtimeType &&
          settings == other.settings &&
          apiTestResult == other.apiTestResult &&
          realtimeTestResult == other.realtimeTestResult &&
          isTesting == other.isTesting &&
          isDirty == other.isDirty;

  @override
  int get hashCode => Object.hash(
        settings,
        apiTestResult,
        realtimeTestResult,
        isTesting,
        isDirty,
      );
}

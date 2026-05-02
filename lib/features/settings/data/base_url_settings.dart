import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiBaseUrlKey = 'base_url_api';
const _realtimeUrlKey = 'base_url_realtime';

@immutable
class BaseUrlSettings {
  const BaseUrlSettings({
    this.apiBaseUrl = '',
    this.realtimeUrl = '',
  });

  /// User-configured API base URL. Empty string means use build-time
  /// default.
  final String apiBaseUrl;

  /// User-configured Realtime/WebSocket base URL. Empty string means use
  /// build-time default.
  final String realtimeUrl;

  bool get hasApiOverride => apiBaseUrl.isNotEmpty;
  bool get hasRealtimeOverride => realtimeUrl.isNotEmpty;

  BaseUrlSettings copyWith({
    String? apiBaseUrl,
    String? realtimeUrl,
  }) {
    return BaseUrlSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      realtimeUrl: realtimeUrl ?? this.realtimeUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseUrlSettings &&
          runtimeType == other.runtimeType &&
          apiBaseUrl == other.apiBaseUrl &&
          realtimeUrl == other.realtimeUrl;

  @override
  int get hashCode => Object.hash(apiBaseUrl, realtimeUrl);
}

abstract class BaseUrlRepository {
  BaseUrlSettings load();
  Future<void> save(BaseUrlSettings settings);
  Future<void> clear();
}

class SharedPrefsBaseUrlRepository implements BaseUrlRepository {
  const SharedPrefsBaseUrlRepository({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;

  @override
  BaseUrlSettings load() {
    return BaseUrlSettings(
      apiBaseUrl: _prefs.getString(_apiBaseUrlKey) ?? '',
      realtimeUrl: _prefs.getString(_realtimeUrlKey) ?? '',
    );
  }

  @override
  Future<void> save(BaseUrlSettings settings) async {
    if (settings.apiBaseUrl.isEmpty) {
      await _prefs.remove(_apiBaseUrlKey);
    } else {
      await _prefs.setString(_apiBaseUrlKey, settings.apiBaseUrl);
    }
    if (settings.realtimeUrl.isEmpty) {
      await _prefs.remove(_realtimeUrlKey);
    } else {
      await _prefs.setString(_realtimeUrlKey, settings.realtimeUrl);
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_apiBaseUrlKey);
    await _prefs.remove(_realtimeUrlKey);
  }
}

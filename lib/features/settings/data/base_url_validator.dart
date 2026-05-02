/// Normalizes and validates base URL input.
///
/// For API URLs: accepts http/https, strips trailing `/`.
/// For Realtime URLs: accepts http/https/ws/wss, auto-normalizes
/// http→ws and https→wss, strips trailing `/`.
class BaseUrlValidator {
  const BaseUrlValidator._();

  /// Validates and normalizes an API base URL.
  ///
  /// Returns the normalized URL or `null` if invalid.
  static String? normalizeApiUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return null;
    }
    return _stripTrailingSlash(trimmed);
  }

  /// Validates and normalizes a Realtime/WebSocket base URL.
  ///
  /// Accepts http/https/ws/wss. Normalizes http→ws and https→wss.
  /// Returns the normalized URL or `null` if invalid.
  static String? normalizeRealtimeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    var url = trimmed;
    final lower = url.toLowerCase();
    if (lower.startsWith('https://')) {
      url = 'wss://${url.substring('https://'.length)}';
    } else if (lower.startsWith('http://')) {
      url = 'ws://${url.substring('http://'.length)}';
    } else if (!lower.startsWith('ws://') && !lower.startsWith('wss://')) {
      return null;
    }
    return _stripTrailingSlash(url);
  }

  static String _stripTrailingSlash(String url) {
    var result = url;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

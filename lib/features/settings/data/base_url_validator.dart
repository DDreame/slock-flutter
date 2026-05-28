/// Normalizes and validates base URL input.
///
/// For API URLs: accepts http/https, strips trailing `/`,
/// and requires a parseable URI with non-empty host.
/// For Realtime URLs: accepts http/https/ws/wss, auto-normalizes
/// http→ws and https→wss, strips trailing `/`,
/// and requires a parseable URI with non-empty host.
class BaseUrlValidator {
  const BaseUrlValidator._();

  /// Validates and normalizes an API base URL.
  ///
  /// Returns the normalized URL, empty string for empty input,
  /// or `null` if invalid.
  static String? normalizeApiUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return null;
    }
    final stripped = _stripTrailingSlash(trimmed);
    if (!_hasNonEmptyHost(stripped)) return null;
    return stripped;
  }

  /// Validates and normalizes a Realtime/WebSocket base URL.
  ///
  /// Accepts http/https/ws/wss. Normalizes http→ws and https→wss.
  /// Returns the normalized URL, empty string for empty input,
  /// or `null` if invalid.
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
    final stripped = _stripTrailingSlash(url);
    if (!_hasNonEmptyHost(stripped)) return null;
    return stripped;
  }

  static String _stripTrailingSlash(String url) {
    var result = url;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Returns `true` when [url] can be parsed as a URI with a
  /// non-empty host component (i.e. not just a bare scheme).
  static bool _hasNonEmptyHost(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.host.isNotEmpty;
  }
}

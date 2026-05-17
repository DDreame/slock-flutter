/// Shared RegExp constants for extracting server and channel IDs from
/// realtime event scope keys.
///
/// These patterns are used across multiple realtime binding files.
/// Promoting them to shared constants avoids re-compiling the same
/// RegExp on every inbound event (~9 allocations on the hot path).
library;

/// Extracts the server ID from a scope key string.
///
/// Matches `"server:<id>"` at the start or after a `/` separator.
/// Example: `"org/server:abc123"` → group(1) = `"abc123"`.
final RegExp serverScopePattern = RegExp(r'(?:^|/)server:([^/]+)');

/// Extracts the channel ID from a scope key string.
///
/// Matches `"channel:<id>"` at the start or after a `/` separator.
/// Example: `"org/channel:xyz789"` → group(1) = `"xyz789"`.
final RegExp channelScopePattern = RegExp(r'(?:^|/)channel:([^/]+)');

import 'package:flutter/foundation.dart';

/// An announcement from the server, shown as a banner at the top of the app.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.body,
    this.dismissible = true,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final bool dismissible;
  final DateTime? createdAt;

  /// Parses an [Announcement] from a JSON map. Returns null if required
  /// fields are missing.
  static Announcement? fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    final body = map['body'];
    final dismissible = map['dismissible'];
    final createdAt = map['createdAt'];
    return Announcement(
      id: id,
      title: title,
      body: body is String && body.isNotEmpty ? body : null,
      dismissible: dismissible is bool ? dismissible : true,
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  /// Parses a list of announcements from API response.
  /// Tries `data['announcements']`, then bare list.
  static List<Announcement> parseList(Object? data) {
    List? rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      final announcements = data['announcements'];
      if (announcements is List) rawList = announcements;
    }
    if (rawList == null) return const [];

    final results = <Announcement>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      final announcement = Announcement.fromMap(map);
      if (announcement != null) results.add(announcement);
    }
    return results;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Announcement &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

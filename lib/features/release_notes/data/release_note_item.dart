import 'package:flutter/foundation.dart';

@immutable
class ReleaseNoteItem {
  const ReleaseNoteItem({
    required this.version,
    required this.title,
    required this.dateLabel,
    required this.highlights,
  });

  final String version;
  final String title;
  final String dateLabel;
  final List<String> highlights;
}

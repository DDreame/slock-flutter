import 'package:flutter/foundation.dart';

enum ReleaseNoteType { feature, fix, improvement, breaking }

@immutable
class ReleaseNoteEntry {
  const ReleaseNoteEntry({required this.type, required this.text});

  final ReleaseNoteType type;
  final String text;
}

@immutable
class ReleaseNoteItem {
  const ReleaseNoteItem({required this.date, required this.items});

  final String date;
  final List<ReleaseNoteEntry> items;
}

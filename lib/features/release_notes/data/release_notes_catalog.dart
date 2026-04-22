import 'package:slock_app/features/release_notes/data/release_note_item.dart';

const releaseNotesCatalog = [
  ReleaseNoteItem(
    version: 'Phase 6',
    title: 'Members and profile expansion landed',
    dateLabel: 'April 2026',
    highlights: [
      'Server member list now has a dedicated surface.',
      'Other-user profiles show richer role and presence details.',
      'Direct-message entry is available from members and profile flows.',
    ],
  ),
  ReleaseNoteItem(
    version: 'Phase 6',
    title: 'Search and channel management foundations landed',
    dateLabel: 'April 2026',
    highlights: [
      'Global search merges local cache hits with remote message search.',
      'Channel create, rename, delete, and leave are available from home.',
      'Scoped routing remains explicit for channels, DMs, and threads.',
    ],
  ),
  ReleaseNoteItem(
    version: 'Phase 5',
    title: 'Notifications and realtime groundwork stabilized',
    dateLabel: 'April 2026',
    highlights: [
      'Push token registration and notification deep-link handling are wired.',
      'Conversation history, realtime updates, and identity hydration were tightened.',
      'Saved messages and billing/settings destinations remain first-class app surfaces.',
    ],
  ),
];

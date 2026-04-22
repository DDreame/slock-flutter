import 'package:flutter/material.dart';
import 'package:slock_app/features/release_notes/data/release_notes_catalog.dart';

class ReleaseNotesPage extends StatelessWidget {
  const ReleaseNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Release Notes')),
      body: ListView.builder(
        key: const ValueKey('release-notes-list'),
        padding: const EdgeInsets.all(16),
        itemCount: releaseNotesCatalog.length,
        itemBuilder: (context, index) {
          final note = releaseNotesCatalog[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.version,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(note.dateLabel),
                  const SizedBox(height: 12),
                  for (final highlight in note.highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_outline, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(highlight)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

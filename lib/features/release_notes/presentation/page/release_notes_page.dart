import 'package:flutter/material.dart';

class ReleaseNotesPage extends StatelessWidget {
  const ReleaseNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Release Notes')),
      body: const Center(child: Text('Release Notes')),
    );
  }
}

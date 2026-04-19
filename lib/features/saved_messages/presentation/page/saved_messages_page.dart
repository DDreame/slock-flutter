import 'package:flutter/material.dart';

class SavedMessagesPage extends StatelessWidget {
  const SavedMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Messages')),
      body: const Center(child: Text('Saved Messages')),
    );
  }
}

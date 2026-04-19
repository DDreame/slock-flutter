import 'package:flutter/material.dart';

class ThreadsPage extends StatelessWidget {
  final String serverId;

  const ThreadsPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Threads')),
      body: Center(child: Text('Threads for server $serverId')),
    );
  }
}

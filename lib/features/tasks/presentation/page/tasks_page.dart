import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  final String serverId;

  const TasksPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Center(child: Text('Tasks for server $serverId')),
    );
  }
}

import 'package:flutter/material.dart';

class ThreadRepliesPage extends StatelessWidget {
  final String threadId;

  const ThreadRepliesPage({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thread Replies')),
      body: Center(child: Text('Replies for thread $threadId')),
    );
  }
}

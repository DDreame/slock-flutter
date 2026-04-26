import 'package:flutter/material.dart';

class FatalBootstrapScreen extends StatelessWidget {
  const FatalBootstrapScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'App Failed to Start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Try restarting the app. If the problem persists, '
                  'reinstall or contact support.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

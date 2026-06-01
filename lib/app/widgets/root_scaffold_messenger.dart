import 'package:flutter/material.dart';

/// Global key for the root [ScaffoldMessenger], attached to the
/// [MaterialApp.router] in main.dart.
///
/// Use this to show snackbars from contexts where a local [BuildContext]
/// is not available (e.g. Riverpod listeners in the router setup).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

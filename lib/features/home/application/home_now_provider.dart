import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time. Override in tests for deterministic
/// duration calculations.
final homeNowProvider = Provider<DateTime>((ref) => DateTime.now());

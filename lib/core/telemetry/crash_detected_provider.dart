import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a previous crash was detected during splash startup.
///
/// Set to `true` by [SplashController] when [CrashMarkerService.hasCrashMarker]
/// returns `true`. Read by [CrashRecoveryWrapper] to show the recovery dialog
/// after the app has finished bootstrapping.
final crashDetectedProvider = StateProvider<bool>((ref) => false);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/voice/application/voice_recording_controller.dart';

/// Invisible widget that keeps [voiceRecordingControllerProvider] alive for
/// the lifetime of its parent widget tree (#772).
///
/// Without this watch, the AutoDispose controller would be garbage-collected
/// after `ref.read()` returns in tap handlers, tearing down the recorder
/// and subscriptions mid-recording.
///
/// Used by ConversationDetailPage. Extracted into its own widget so the
/// lifecycle binding is directly testable without pumping the entire page.
class VoiceRecordingLifecycleBinding extends ConsumerWidget {
  const VoiceRecordingLifecycleBinding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This watch is the production-critical line (#772).
    ref.watch(voiceRecordingControllerProvider);
    return child;
  }
}

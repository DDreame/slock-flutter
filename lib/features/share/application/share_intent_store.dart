import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:slock_app/features/share/data/shared_content.dart';

/// Maps a [SharedMediaType] from the plugin to our domain [SharedContentType].
SharedContentType _mapMediaType(SharedMediaType type) {
  return switch (type) {
    SharedMediaType.image => SharedContentType.image,
    SharedMediaType.video => SharedContentType.video,
    SharedMediaType.text => SharedContentType.text,
    SharedMediaType.url => SharedContentType.url,
    SharedMediaType.file => SharedContentType.file,
  };
}

/// Converts a list of [SharedMediaFile] from the plugin into a [SharedContent].
SharedContent parseSharedMedia(List<SharedMediaFile> files) {
  if (files.isEmpty) return const SharedContent(items: []);
  return SharedContent(
    items: files
        .map(
          (f) => SharedContentItem(
            type: _mapMediaType(f.type),
            path: f.path,
            mimeType: f.mimeType,
            thumbnail: f.thumbnail,
          ),
        )
        .toList(),
  );
}

/// Store managing pending shared content from platform share intents.
///
/// Listens to both:
/// - [ReceiveSharingIntent.getInitialMedia] — cold-start intent
/// - [ReceiveSharingIntent.getMediaStream] — foreground intent stream
///
/// The pending content is consumed (cleared) when the user sends it or
/// dismisses the share flow.
class ShareIntentStore extends Notifier<SharedContent?> {
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  @override
  SharedContent? build() => null;

  /// Start listening for share intents. Call once during app startup.
  Future<void> initialize() async {
    // Handle cold-start intent.
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      state = parseSharedMedia(initial);
    }

    // Listen for foreground intents.
    _subscription?.cancel();
    _subscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        state = parseSharedMedia(files);
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
  }

  /// Consume the pending shared content (after user sends or dismisses).
  void consume() {
    state = null;
    ReceiveSharingIntent.instance.reset();
  }

  /// Sets shared content programmatically (e.g., from screenshot export).
  ///
  /// Unlike [initialize], this does not listen for platform intents — it
  /// simply seeds the store with the given [content] so the share-target
  /// picker can consume it.
  void setContent(SharedContent content) {
    state = content;
  }
}

/// App-scoped provider for [ShareIntentStore].
final shareIntentStoreProvider =
    NotifierProvider<ShareIntentStore, SharedContent?>(ShareIntentStore.new);

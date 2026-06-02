/// Application-layer re-export of [typingRealtimeBindingProvider].
///
/// Keeps the presentation layer decoupled from the data layer — presentation
/// files should import this file instead of the data-layer provider directly.
library;

export 'package:slock_app/features/conversation/data/typing_realtime_binding.dart'
    show typingRealtimeBindingProvider;

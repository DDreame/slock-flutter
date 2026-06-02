/// Application-layer re-export of audio player pool types and provider.
///
/// Keeps the presentation layer decoupled from the data layer — presentation
/// files should import this file instead of the data-layer provider directly.
library;

export 'package:slock_app/features/voice/data/audio_player_service.dart'
    show
        audioAttachmentPlayerPoolProvider,
        AudioAttachmentPlayerPool,
        AudioPlayerController,
        AudioPlaybackState;

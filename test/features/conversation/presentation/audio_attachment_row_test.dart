import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/audio_player_service.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('AudioAttachmentRow', () {
    testWidgets('tap play transitions audio row to playing', (tester) async {
      final player = _FakeAudioPlayerController();

      await tester.pumpWidget(_audioHarness([player]));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('voice-play-pause')));
      await tester.pump();

      expect(player.playCount, 1);
      expect(player.state, AudioPlaybackState.playing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('tap pause transitions audio row to paused', (tester) async {
      final player = _FakeAudioPlayerController();

      await tester.pumpWidget(_audioHarness([player]));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('voice-play-pause')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('voice-play-pause')));
      await tester.pump();

      expect(player.playCount, 1);
      expect(player.pauseCount, 1);
      expect(player.state, AudioPlaybackState.paused);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('player error shows indicator and snackbar without crashing',
        (tester) async {
      final player = _FakeAudioPlayerController(failOnPlay: true);

      await tester.pumpWidget(_audioHarness([player]));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('voice-play-pause')));
      await tester.pump();

      expect(player.playCount, 1);
      expect(player.state, AudioPlaybackState.error);
      expect(
          find.byKey(const ValueKey('audio-playback-error')), findsOneWidget);
      expect(find.text('Audio playback failed'), findsOneWidget);
    });

    testWidgets('starting second audio stops previous on shared player',
        (tester) async {
      final player = _FakeAudioPlayerController();
      var createdPlayers = 0;

      await tester.pumpWidget(
        _audioHarness(
          [player],
          onCreatePlayer: () => createdPlayers++,
          attachments: const [
            MessageAttachment(
              name: 'first.m4a',
              type: 'audio/m4a',
              url: 'https://example.test/first.m4a',
            ),
            MessageAttachment(
              name: 'second.m4a',
              type: 'audio/m4a',
              url: 'https://example.test/second.m4a',
            ),
          ],
        ),
      );
      await tester.pump();

      final buttons = find.byKey(const ValueKey('voice-play-pause'));
      expect(buttons, findsNWidgets(2));
      expect(createdPlayers, 1);

      await tester.tap(buttons.at(0));
      await tester.pump();
      expect(player.playCount, 1);
      expect(player.currentPath, 'https://example.test/first.m4a');
      expect(player.state, AudioPlaybackState.playing);

      await tester.tap(buttons.at(1));
      await tester.pump();

      expect(player.stopCount, 1);
      expect(player.playCount, 2);
      expect(player.currentPath, 'https://example.test/second.m4a');
      expect(player.state, AudioPlaybackState.playing);
    });

    testWidgets('many audio rows share one pooled player', (tester) async {
      final player = _FakeAudioPlayerController();
      var createdPlayers = 0;

      await tester.pumpWidget(
        _audioHarness(
          [player],
          onCreatePlayer: () => createdPlayers++,
          attachments: List.generate(
            12,
            (index) => MessageAttachment(
              name: 'voice_$index.m4a',
              type: 'audio/m4a',
              url: 'https://example.test/voice_$index.m4a',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('voice-play-pause')), findsNWidgets(12));
      expect(createdPlayers, 1);
    });

    testWidgets('disposing audio rows releases pooled player', (tester) async {
      final player = _FakeAudioPlayerController();

      await tester.pumpWidget(_audioHarness([player]));
      await tester.pump();
      expect(player.disposeCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(player.disposeCount, 1);
    });

    testWidgets('cached waveform row read refreshes LRU recency',
        (tester) async {
      final container = ProviderContainer();
      final subscription = container.listen(
        voiceWaveformCacheProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      final notifier = container.read(voiceWaveformCacheProvider.notifier);
      for (var i = 0; i < VoiceWaveformCacheNotifier.maxSize; i++) {
        notifier.put('voice_$i.m4a', [i.toDouble()]);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AttachmentSection(
                attachments: [
                  MessageAttachment(
                    name: 'voice_0.m4a',
                    type: 'audio/m4a',
                    url: 'https://example.test/voice_0.m4a',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      notifier.put('voice_50.m4a', [50.0]);

      final cache = container.read(voiceWaveformCacheProvider);
      expect(cache, hasLength(VoiceWaveformCacheNotifier.maxSize));
      expect(cache.containsKey('voice_0.m4a'), isTrue,
          reason: 'Real audio row cache read must refresh recency');
      expect(cache.containsKey('voice_1.m4a'), isFalse,
          reason: 'The true LRU entry should be evicted instead');
      expect(cache.containsKey('voice_50.m4a'), isTrue);
    });
  });
}

Widget _audioHarness(
  List<_FakeAudioPlayerController> players, {
  VoidCallback? onCreatePlayer,
  List<MessageAttachment> attachments = const [
    MessageAttachment(
      name: 'voice.m4a',
      type: 'audio/m4a',
      url: 'https://example.test/voice.m4a',
    ),
  ],
}) {
  var index = 0;
  return ProviderScope(
    overrides: [
      audioPlayerServiceFactoryProvider.overrideWithValue(() {
        onCreatePlayer?.call();
        return players[index++];
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: AttachmentSection(attachments: attachments),
          ),
        ),
      ),
    ),
  );
}

class _FakeAudioPlayerController implements AudioPlayerController {
  _FakeAudioPlayerController({this.failOnPlay = false});

  final bool failOnPlay;
  final _stateController = StreamController<AudioPlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  int loadCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  AudioPlaybackState state = AudioPlaybackState.stopped;

  @override
  String? currentPath;

  @override
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<Duration?> load(String path) async {
    loadCount++;
    currentPath = path;
    const duration = Duration(seconds: 12);
    _durationController.add(duration);
    return duration;
  }

  @override
  Future<void> play(String path) async {
    playCount++;
    currentPath = path;
    _setState(
        failOnPlay ? AudioPlaybackState.error : AudioPlaybackState.playing);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    if (state == AudioPlaybackState.playing) {
      _setState(AudioPlaybackState.paused);
    }
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _setState(AudioPlaybackState.playing);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _setState(AudioPlaybackState.stopped);
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  void _setState(AudioPlaybackState nextState) {
    state = nextState;
    _stateController.add(nextState);
  }
}

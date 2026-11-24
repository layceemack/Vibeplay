import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import 'screens/home_screen.dart';
import 'services/library_store.dart';

late AudioPlayer audioPlayer;
late VibeAudioHandler vibeAudioHandler;
final libraryStore = LibraryStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await libraryStore.init();

  audioPlayer = AudioPlayer();
  await AudioService.init(
    builder: () => vibeAudioHandler = VibeAudioHandler(audioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vibeplay.audio',
      androidNotificationChannelName: 'VibePlay music playback',
      androidNotificationChannelDescription: 'Controls for music playing in VibePlay',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const VibePlayApp());
}

class VibeAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  VibeAudioHandler(this.player) {
    player.playbackEventStream.listen((_) => _broadcastState());
    player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  final AudioPlayer player;

  void setQueueItems(List<MediaItem> items, {int initialIndex = 0}) {
    queue.add(items);
    if (items.isNotEmpty && initialIndex >= 0 && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
    }
  }

  void _broadcastState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (player.hasNext) await player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      await player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    });
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await player.setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);
  }
}

class VibePlayApp extends StatelessWidget {
  const VibePlayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VibePlay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1DB954),
            secondary: Color(0xFF1DB954),
            surface: Color(0xFF1E1E1E),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            foregroundColor: Colors.white,
            centerTitle: false,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF1E1E1E),
            indicatorColor: Color(0x3321C765),
          ),
        ),
        home: const HomeScreen(),
      );
}

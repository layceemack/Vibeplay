import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';

/// Wraps just_audio. Thanks to just_audio_background the audio keeps playing when the app
/// is minimised or the screen is locked, and Android shows a media notification
/// (artwork, title, artist, previous / play-pause / next) backed by a foreground service.
class PlayerService extends ChangeNotifier {
  PlayerService() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];
  final StreamController<String> _messages = StreamController<String>.broadcast();

  List<Song> _queue = <Song>[];
  List<int> _queueIds = <int>[];
  Song? _current;
  bool _hasSource = false;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool _handlingComplete = false;
  int _errorStreak = 0;

  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;
  int _sleepMinutes = 0;

  // ------------------------------------------------------------------ getters

  Song? get current => _current;
  List<Song> get queue => _queue;
  bool get shuffleEnabled => _shuffle;
  LoopMode get loopMode => _loopMode;
  bool get isPlaying =>
      _player.playing && _player.processingState != ProcessingState.completed;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Short messages (errors, sleep timer) that the UI can show in a SnackBar.
  Stream<String> get messages => _messages.stream;

  int get sleepMinutes => _sleepMinutes;
  DateTime? get sleepEndsAt => _sleepEndsAt;

  // --------------------------------------------------------------------- init

  void _init() {
    _subscriptions.add(_player.currentIndexStream.listen((int? index) {
      if (index != null && index >= 0 && index < _queue.length) {
        _current = _queue[index];
        notifyListeners();
      }
    }));

    _subscriptions.add(_player.playerStateStream.listen((PlayerState state) {
      if (state.processingState == ProcessingState.ready) {
        _errorStreak = 0;
      }
      if (state.processingState == ProcessingState.completed) {
        unawaited(_onQueueCompleted());
      }
      notifyListeners();
    }));

    _subscriptions.add(_player.playbackEventStream.listen(
      (PlaybackEvent event) {},
      onError: (Object error, StackTrace stackTrace) {
        _onPlaybackError(error);
      },
    ));

    // Backup for the sleep timer: also checks the wall clock while audio is playing.
    _subscriptions.add(_player.positionStream.listen((Duration _) {
      final DateTime? end = _sleepEndsAt;
      if (end != null && !DateTime.now().isBefore(end)) {
        unawaited(_onSleepTimerFired());
      }
    }));
  }

  AudioSource _toSource(Song song) {
    return AudioSource.uri(
      Uri.parse(song.uri),
      tag: MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.durationMs > 0 ? Duration(milliseconds: song.durationMs) : null,
        artUri: song.albumId > 0 ? Uri.parse(song.albumArtUri) : null,
      ),
    );
  }

  // ----------------------------------------------------------------- playback

  /// Plays [list] starting at [index]. The whole list becomes the play queue,
  /// so Next / Previous move through the list the user tapped in.
  Future<void> playFromList(List<Song> list, int index) async {
    if (list.isEmpty || index < 0 || index >= list.length) return;
    final List<int> ids = list.map((Song s) => s.id).toList();

    // Same queue is already loaded: just jump to the tapped song.
    if (_hasSource && listEquals(ids, _queueIds)) {
      _current = list[index];
      notifyListeners();
      try {
        await _player.seek(Duration.zero, index: index);
        unawaited(_player.play());
      } catch (e) {
        _reportLoadError(e);
      }
      return;
    }

    _queue = List<Song>.from(list);
    _queueIds = ids;
    _current = _queue[index];
    _hasSource = false;
    notifyListeners();

    try {
      final ConcatenatingAudioSource source = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: _queue.map(_toSource).toList(),
      );
      await _player.setAudioSource(
        source,
        initialIndex: index,
        initialPosition: Duration.zero,
      );
      _hasSource = true;
      if (_shuffle) {
        await _player.shuffle();
      }
      unawaited(_player.play());
    } catch (e) {
      _reportLoadError(e);
    }
  }

  Future<void> togglePlayPause() async {
    if (_current == null || !_hasSource) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
  }

  Future<void> seek(Duration position) async {
    if (!_hasSource) return;
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_queue.isEmpty || !_hasSource) return;
    if (_loopMode == LoopMode.one) {
      // In "repeat one" just_audio would replay the same song; a manual Next should advance.
      await _player.setLoopMode(LoopMode.all);
      await _player.seekToNext();
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty || !_hasSource) return;
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_loopMode == LoopMode.one) {
      await _player.setLoopMode(LoopMode.all);
      await _player.seekToPrevious();
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
    await _player.setShuffleModeEnabled(_shuffle);
    if (_shuffle && _hasSource) {
      await _player.shuffle();
    }
  }

  /// Off -> All -> One -> Off
  Future<void> cycleRepeat() async {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        break;
      case LoopMode.one:
        _loopMode = LoopMode.off;
        break;
    }
    notifyListeners();
    await _player.setLoopMode(_loopMode);
  }

  Future<void> _onQueueCompleted() async {
    if (_handlingComplete || _queue.isEmpty) return;
    _handlingComplete = true;
    try {
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    } catch (_) {
      // Ignore - the player may already be disposed or reloading.
    } finally {
      _handlingComplete = false;
    }
  }

  void _onPlaybackError(Object error) {
    debugPrint('Playback error: $error');
    _errorStreak++;
    if (_errorStreak <= 3 && _hasSource && _player.hasNext) {
      _messages.add('Skipped a song that could not be played');
      unawaited(next());
    } else if (_errorStreak == 4) {
      _messages.add('Playback error - some songs could not be played');
    }
  }

  void _reportLoadError(Object error) {
    debugPrint('Could not load song: $error');
    _messages.add('Could not play this song');
  }

  // -------------------------------------------------------------- sleep timer

  /// [minutes] is 0 (off), 15, 30 or 60.
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _sleepMinutes = minutes;

    if (minutes > 0) {
      _sleepEndsAt = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        unawaited(_onSleepTimerFired());
      });
    }
    notifyListeners();
  }

  Future<void> _onSleepTimerFired() async {
    if (_sleepEndsAt == null) return; // already handled
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _sleepMinutes = 0;
    notifyListeners();

    try {
      // Short fade-out, then stop playback through the native player.
      for (int i = 9; i >= 0; i--) {
        await _player.setVolume(i / 10.0);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await _player.pause();
    } catch (_) {
      // Fall through and restore the volume below.
    } finally {
      await _player.setVolume(1.0);
    }
    _messages.add('Sleep timer: playback stopped');
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      sub.cancel();
    }
    _messages.close();
    _player.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../main.dart';
import '../models/song.dart';
import '../widgets/album_art.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.songs});
  final List<Song> songs;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  StreamSubscription? _playerSub;
  int _repeat = 0;
  bool _shuffle = false;
  bool _favourite = false;

  Song? get _currentSong {
    final index = audioPlayer.currentIndex;
    if (index == null || index < 0 || index >= widget.songs.length) return null;
    return widget.songs[index];
  }

  @override
  void initState() {
    super.initState();
    _syncFavourite();
    _playerSub = audioPlayer.playerStateStream.listen((_) {
      if (mounted) setState(() {});
      _syncFavourite();
    });
  }

  Future<void> _syncFavourite() async {
    final song = _currentSong;
    if (song == null) return;
    final value = libraryStore.isFavourite(song.id);
    if (mounted && value != _favourite) setState(() => _favourite = value);
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: StreamBuilder<SequenceState?>(
        stream: audioPlayer.sequenceStateStream,
        builder: (context, snapshot) {
          final song = _currentSong;
          if (song == null) {
            return const Center(child: Text('Nothing playing'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  const Spacer(),
                  Center(child: AlbumArt(albumId: song.albumId, size: 270, radius: 20)),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _favourite ? 'Remove from favourites' : 'Add to favourites',
                        onPressed: () async {
                          await libraryStore.toggleFavourite(song.id);
                          if (mounted) setState(() => _favourite = libraryStore.isFavourite(song.id));
                        },
                        icon: Icon(_favourite ? Icons.favorite : Icons.favorite_border,
                            color: _favourite ? const Color(0xFF1DB954) : Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  StreamBuilder<Duration>(
                    stream: audioPlayer.positionStream,
                    initialData: audioPlayer.position,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      final total = audioPlayer.duration ?? Duration.zero;
                      final max = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                      return Column(
                        children: [
                          Slider(
                            value: position.inMilliseconds.toDouble().clamp(0.0, max).toDouble(),
                            max: max,
                            onChanged: (value) => audioPlayer.seek(Duration(milliseconds: value.round())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(_time(position)), Text(_time(total))],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Shuffle',
                        onPressed: () async {
                          _shuffle = !_shuffle;
                          await audioPlayer.setShuffleModeEnabled(_shuffle);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(Icons.shuffle,
                            color: _shuffle ? const Color(0xFF1DB954) : Colors.white),
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        iconSize: 34,
                        onPressed: audioPlayer.hasPrevious ? audioPlayer.seekToPrevious : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      IconButton(
                        tooltip: audioPlayer.playing ? 'Pause' : 'Play',
                        iconSize: 68,
                        onPressed: () => audioPlayer.playing ? audioPlayer.pause() : audioPlayer.play(),
                        icon: Icon(
                          audioPlayer.playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: const Color(0xFF1DB954),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        iconSize: 34,
                        onPressed: audioPlayer.hasNext ? audioPlayer.seekToNext : null,
                        icon: const Icon(Icons.skip_next),
                      ),
                      IconButton(
                        tooltip: const ['Repeat off', 'Repeat all', 'Repeat one'][_repeat],
                        onPressed: () async {
                          _repeat = (_repeat + 1) % 3;
                          await audioPlayer.setLoopMode(
                              [LoopMode.off, LoopMode.all, LoopMode.one][_repeat]);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                          _repeat == 2 ? Icons.repeat_one : Icons.repeat,
                          color: _repeat == 0 ? Colors.white : const Color(0xFF1DB954),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

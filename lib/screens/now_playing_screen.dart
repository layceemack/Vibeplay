import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/artwork.dart';

/// Full-screen player: large artwork, seek bar and all controls.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerService player = context.watch<PlayerService>();
    final StorageService storage = context.watch<StorageService>();
    final Song? song = player.current;

    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold();
    }

    final bool isFavourite = storage.isFavourite(song.id);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double side =
                          math.min(constraints.maxWidth, constraints.maxHeight);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withAlpha(140),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Artwork(
                          song: song,
                          size: side,
                          radius: 20,
                          pixelSize: 720,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
                    iconSize: 30,
                    icon: Icon(
                      isFavourite ? Icons.favorite : Icons.favorite_border,
                      color: isFavourite ? AppColors.accent : Colors.white,
                    ),
                    onPressed: () => storage.toggleFavourite(song.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SeekBar(player: player, song: song),
              const SizedBox(height: 8),
              _Controls(player: player),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player, required this.song});

  final PlayerService player;
  final Song song;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Position (ms) while the user is dragging the thumb; null otherwise.
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final PlayerService player = widget.player;

    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (BuildContext context, AsyncSnapshot<Duration?> durationSnapshot) {
        final Duration? reported = durationSnapshot.data;
        final Duration total = (reported != null && reported > Duration.zero)
            ? reported
            : Duration(milliseconds: widget.song.durationMs);

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (BuildContext context, AsyncSnapshot<Duration> positionSnapshot) {
            final Duration position = positionSnapshot.data ?? Duration.zero;
            final double maxMs = math.max(total.inMilliseconds, 1).toDouble();
            final double valueMs =
                (_dragMs ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs).toDouble();

            return Column(
              children: <Widget>[
                Slider(
                  min: 0,
                  max: maxMs,
                  value: valueMs,
                  onChangeStart: (double v) => setState(() => _dragMs = v),
                  onChanged: (double v) => setState(() => _dragMs = v),
                  onChangeEnd: (double v) async {
                    await player.seek(Duration(milliseconds: v.round()));
                    if (mounted) {
                      setState(() => _dragMs = null);
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        formatDuration(Duration(milliseconds: valueMs.round())),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatDuration(total),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final PlayerService player;

  String _repeatLabel(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return 'Off';
      case LoopMode.all:
        return 'All';
      case LoopMode.one:
        return 'One';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool shuffle = player.shuffleEnabled;
    final LoopMode loop = player.loopMode;
    final bool showSpinner = player.isBuffering && !player.isPlaying;

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
              iconSize: 28,
              color: shuffle ? AppColors.accent : AppColors.textSecondary,
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: player.toggleShuffle,
            ),
            IconButton(
              tooltip: 'Previous',
              iconSize: 42,
              color: Colors.white,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: player.previous,
            ),
            Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: player.togglePlayPause,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Center(
                    child: showSpinner
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 46,
                            color: Colors.black,
                          ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              iconSize: 42,
              color: Colors.white,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: player.next,
            ),
            IconButton(
              tooltip: 'Repeat ${_repeatLabel(loop)}',
              iconSize: 28,
              color: loop == LoopMode.off ? AppColors.textSecondary : AppColors.accent,
              icon: Icon(
                loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              ),
              onPressed: player.cycleRepeat,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Shuffle ${shuffle ? 'On' : 'Off'}  •  Repeat ${_repeatLabel(loop)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

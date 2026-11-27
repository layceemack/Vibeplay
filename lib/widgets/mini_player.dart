import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../screens/now_playing_screen.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../utils/routes.dart';
import 'artwork.dart';

/// Bottom bar shown while a song is loaded. Tap it to open the full player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerService player = context.watch<PlayerService>();
    final Song? song = player.current;
    if (song == null) return const SizedBox.shrink();

    return Material(
      color: AppColors.card,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => Navigator.of(context).push(slideUpRoute(const NowPlayingScreen())),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _MiniProgress(player: player, song: song),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: <Widget>[
                    Artwork(song: song, size: 46, radius: 8, pixelSize: 140),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: player.isPlaying ? 'Pause' : 'Play',
                      iconSize: 34,
                      color: Colors.white,
                      icon: Icon(
                        player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      ),
                      onPressed: player.togglePlayPause,
                    ),
                    IconButton(
                      tooltip: 'Next',
                      iconSize: 30,
                      color: Colors.white,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: player.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.player, required this.song});

  final PlayerService player;
  final Song song;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (BuildContext context, AsyncSnapshot<Duration?> durationSnapshot) {
        final Duration? reported = durationSnapshot.data;
        final int totalMs = (reported != null && reported > Duration.zero)
            ? reported.inMilliseconds
            : song.durationMs;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (BuildContext context, AsyncSnapshot<Duration> positionSnapshot) {
            final int positionMs = (positionSnapshot.data ?? Duration.zero).inMilliseconds;
            final double value =
                totalMs <= 0 ? 0.0 : (positionMs / totalMs).clamp(0.0, 1.0).toDouble();
            return LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: AppColors.cardHigh,
              color: AppColors.accent,
            );
          },
        );
      },
    );
  }
}

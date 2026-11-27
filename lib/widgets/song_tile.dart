import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'artwork.dart';

/// One row in a song list: artwork, title, artist and duration.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    required this.onLongPress,
    this.trailing,
  });

  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Artwork(song: song, size: 52, radius: 8, pixelSize: 160),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMs(song.durationMs),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

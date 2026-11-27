import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

class FavouritesTab extends StatelessWidget {
  const FavouritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final StorageService storage = context.watch<StorageService>();
    final LibraryService library = context.watch<LibraryService>();
    final int? currentId =
        context.select<PlayerService, int?>((PlayerService p) => p.current?.id);

    final List<Song> songs =
        storage.favouriteIdsOrdered.map(library.byId).whereType<Song>().toList();

    if (songs.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'No favourites yet',
        message:
            'Tap the heart in the player, or long-press any song and choose "Add to favourites".',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: songs.length,
      itemExtent: 68,
      itemBuilder: (BuildContext context, int index) {
        final Song song = songs[index];
        return SongTile(
          song: song,
          isCurrent: song.id == currentId,
          onTap: () => context.read<PlayerService>().playFromList(songs, index),
          onLongPress: () => showSongActions(context, song),
          trailing: IconButton(
            tooltip: 'Remove from favourites',
            icon: const Icon(Icons.favorite, color: AppColors.accent),
            onPressed: () => storage.toggleFavourite(song.id),
          ),
        );
      },
    );
  }
}

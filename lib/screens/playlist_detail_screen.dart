import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final StorageService storage = context.watch<StorageService>();
    final LibraryService library = context.watch<LibraryService>();
    final int? currentId =
        context.select<PlayerService, int?>((PlayerService p) => p.current?.id);
    final Playlist? playlist = storage.playlistById(playlistId);

    if (playlist == null) {
      // The playlist was deleted - leave this screen.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold();
    }

    final List<Song> songs =
        playlist.songIds.map(library.byId).whereType<Song>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: 'Delete playlist',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final bool confirmed = await confirmDeletePlaylist(context, playlist);
              if (confirmed) {
                await storage.deletePlaylist(playlist.id);
              }
            },
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'This playlist is empty',
              message: 'Long-press any song in your library and choose "Add to playlist".',
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.read<PlayerService>().playFromList(songs, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: songs.length,
                    itemExtent: 68,
                    itemBuilder: (BuildContext context, int index) {
                      final Song song = songs[index];
                      return SongTile(
                        song: song,
                        isCurrent: song.id == currentId,
                        onTap: () =>
                            context.read<PlayerService>().playFromList(songs, index),
                        onLongPress: () => showSongActions(context, song),
                        trailing: IconButton(
                          tooltip: 'Remove from playlist',
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () =>
                              storage.removeSongFromPlaylist(playlist.id, song.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

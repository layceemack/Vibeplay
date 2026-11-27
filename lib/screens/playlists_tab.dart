import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_actions.dart';
import 'playlist_detail_screen.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final StorageService storage = context.watch<StorageService>();
    final List<Playlist> playlists = storage.playlists;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final String? name = await promptPlaylistName(context);
                if (name != null) {
                  await storage.createPlaylist(name);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Playlist'),
            ),
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              ? const EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: 'No playlists yet',
                  message:
                      'Create a playlist, then long-press any song and choose "Add to playlist".',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  itemCount: playlists.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Playlist playlist = playlists[index];
                    final int count = playlist.songIds.length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.cardHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.queue_music_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          title: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$count ${count == 1 ? 'song' : 'songs'}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete playlist',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final bool confirmed =
                                  await confirmDeletePlaylist(context, playlist);
                              if (confirmed) {
                                await storage.deletePlaylist(playlist.id);
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext _) =>
                                    PlaylistDetailScreen(playlistId: playlist.id),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

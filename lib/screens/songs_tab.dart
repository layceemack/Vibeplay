import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

class SongsTab extends StatefulWidget {
  const SongsTab({super.key});

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab> with AutomaticKeepAliveClientMixin<SongsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _statusText(LibraryService library) {
    if (library.error != null) return library.error!;
    final int total = library.totalCount;
    final int shown = library.songs.length;
    if (library.query.trim().isNotEmpty) {
      return '$shown of $total songs';
    }
    return '$total ${total == 1 ? 'song' : 'songs'} found';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final LibraryService library = context.watch<LibraryService>();
    final int? currentId =
        context.select<PlayerService, int?>((PlayerService p) => p.current?.id);
    final List<Song> songs = library.songs;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: library.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search title or artist',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        library.setQuery('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: library.isScanning
                    ? const Row(
                        children: <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Scanning your music...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    : Text(
                        _statusText(library),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
              ),
              PopupMenuButton<SortMode>(
                tooltip: 'Sort songs',
                initialValue: library.sortMode,
                onSelected: library.setSortMode,
                itemBuilder: (BuildContext context) {
                  return SortMode.values.map((SortMode mode) {
                    return PopupMenuItem<SortMode>(
                      value: mode,
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 24,
                            child: mode == library.sortMode
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: AppColors.accent,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(sortLabel(mode)),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.sort_rounded, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        sortLabel(library.sortMode),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: library.isScanning ? null : () => library.scan(deep: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Rescan'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildList(context, library, songs, currentId)),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    LibraryService library,
    List<Song> songs,
    int? currentId,
  ) {
    if (library.isScanning && library.totalCount == 0) {
      return const EmptyState(
        icon: Icons.library_music_rounded,
        title: 'Scanning your music...',
        message: 'Looking through your device for songs.',
      );
    }

    if (songs.isEmpty) {
      if (library.query.trim().isNotEmpty) {
        return const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: 'Try a different title or artist.',
        );
      }
      return EmptyState(
        icon: Icons.music_off_rounded,
        title: 'No music found',
        message: 'VibePlay looks for .mp3, .m4a, .wav, .aac and .flac files on your device.',
        action: FilledButton.icon(
          onPressed: library.isScanning ? null : () => library.scan(deep: true),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Rescan'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: songs.length,
      itemExtent: 68,
      itemBuilder: (BuildContext context, int index) {
        final Song song = songs[index];
        return SongTile(
          song: song,
          isCurrent: song.id == currentId,
          onTap: () {
            FocusScope.of(context).unfocus();
            context.read<PlayerService>().playFromList(songs, index);
          },
          onLongPress: () => showSongActions(context, song),
        );
      },
    );
  }
}

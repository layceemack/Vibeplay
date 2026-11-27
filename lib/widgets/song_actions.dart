import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'artwork.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Bottom sheet shown on long-press: favourite / add to playlist.
Future<void> showSongActions(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Consumer<StorageService>(
          builder: (BuildContext _, StorageService storage, Widget? __) {
            final bool isFav = storage.isFavourite(song.id);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Artwork(song: song, size: 48, radius: 8, pixelSize: 128),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppColors.accent : Colors.white,
                  ),
                  title: Text(isFav ? 'Remove from favourites' : 'Add to favourites'),
                  onTap: () {
                    storage.toggleFavourite(song.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Add to playlist'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (context.mounted) {
                      showPlaylistPicker(context, song);
                    }
                  },
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

/// Bottom sheet listing playlists so a song can be added to one (or a new one).
Future<void> showPlaylistPicker(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
          ),
          child: Consumer<StorageService>(
            builder: (BuildContext _, StorageService storage, Widget? __) {
              final List<Playlist> playlists = storage.playlists;
              return ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Add to playlist',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black),
                    ),
                    title: const Text('New playlist'),
                    onTap: () async {
                      final String? name = await promptPlaylistName(sheetContext);
                      if (name == null) return;
                      final Playlist created = await storage.createPlaylist(name);
                      await storage.addSongToPlaylist(created.id, song.id);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      if (context.mounted) _toast(context, 'Added to "${created.name}"');
                    },
                  ),
                  for (final Playlist playlist in playlists)
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded, color: AppColors.accent),
                      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${playlist.songIds.length} ${playlist.songIds.length == 1 ? 'song' : 'songs'}',
                      ),
                      onTap: () async {
                        final bool added =
                            await storage.addSongToPlaylist(playlist.id, song.id);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        if (context.mounted) {
                          _toast(
                            context,
                            added
                                ? 'Added to "${playlist.name}"'
                                : 'Already in "${playlist.name}"',
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// Asks for a playlist name. Returns null when cancelled.
Future<String?> promptPlaylistName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => const _NameDialog(),
  );
}

Future<bool> confirmDeletePlaylist(BuildContext context, Playlist playlist) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete playlist?'),
        content: Text('"${playlist.name}" will be deleted. Your songs stay on your device.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (String _) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

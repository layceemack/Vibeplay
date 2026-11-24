import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../main.dart';
import '../models/song.dart';
import '../services/native_music_service.dart';
import '../widgets/album_art.dart';
import 'player_screen.dart';

enum LibraryTab { songs, favourites, playlists }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final NativeMusicService _native = NativeMusicService();
  final TextEditingController _search = TextEditingController();
  List<Song> _songs = [];
  bool _scanning = false;
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  String _sort = 'Title';
  LibraryTab _tab = LibraryTab.songs;
  Timer? _sleepTimer;
  int? _sleepMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _initialize() async {
    _permissionGranted = await _native.hasAudioPermission();
    if (!_permissionGranted) {
      final permission = await _native.requestAudioPermission();
      _permissionGranted = permission.granted;
      _permissionPermanentlyDenied = permission.permanentlyDenied;
    }
    if (_permissionGranted) {
      await _native.requestNotificationPermission();
      await _scan();
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshPermission() async {
    final granted = await _native.hasAudioPermission();
    if (granted && !_permissionGranted) {
      _permissionGranted = true;
      await _scan();
    }
    if (mounted) setState(() => _permissionGranted = granted);
  }

  Future<void> _grantPermission() async {
    final state = await _native.requestAudioPermission();
    if (state.granted) {
      _permissionGranted = true;
      _permissionPermanentlyDenied = false;
      await _native.requestNotificationPermission();
      await _scan();
    } else {
      _permissionPermanentlyDenied = state.permanentlyDenied;
      if (_permissionPermanentlyDenied) {
        await _showSettingsDialog();
      } else if (mounted) {
        _showMessage('Permission is required to find music on your device.');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _showSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission needed to find your music'),
        content: const Text('Allow music and audio access in Android App Settings to scan your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _native.openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    if (!_permissionGranted) return;
    setState(() => _scanning = true);
    try {
      final found = await _native.scanAudio();
      if (!mounted) return;
      setState(() {
        _songs = found;
        _scanning = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _showMessage('Could not scan audio. Please check permission and try again.');
    }
  }

  List<Song> get _filteredSongs {
    Iterable<Song> result = _songs;
    if (_tab == LibraryTab.favourites) {
      final favourites = libraryStore.favourites;
      result = result.where((song) => favourites.contains(song.id));
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((song) =>
          song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query));
    }
    final list = result.toList();
    switch (_sort) {
      case 'Artist':
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case 'Date Added':
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      default:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  Future<void> _playSong(Song song) async {
    final index = _songs.indexWhere((item) => item.id == song.id);
    if (index < 0) return;
    final mediaItems = _songs.map((item) => MediaItem(
      id: item.uri,
      title: item.title,
      artist: item.artist,
      album: item.album,
      duration: Duration(milliseconds: item.durationMs),
      artUri: item.albumId >= 0
          ? Uri.parse('content://media/external/audio/albumart/${item.albumId}')
          : null,
    )).toList();

    final source = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: _songs.map((item) => AudioSource.uri(
        Uri.parse(item.uri),
        tag: MediaItem(
          id: item.uri,
          title: item.title,
          artist: item.artist,
          album: item.album,
          duration: Duration(milliseconds: item.durationMs),
          artUri: item.albumId >= 0
              ? Uri.parse('content://media/external/audio/albumart/${item.albumId}')
              : null,
        ),
      )).toList(),
    );

    try {
      await audioPlayer.setAudioSource(source, initialIndex: index);
      vibeAudioHandler.setQueueItems(mediaItems, initialIndex: index);
      await audioPlayer.play();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(songs: _songs),
      ));
    } catch (_) {
      _showMessage('Unable to play this audio file. It may have been moved or is unsupported.');
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await libraryStore.createPlaylist(name);
      if (mounted) setState(() {});
    } on StateError catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _addToPlaylist(Song song) async {
    final playlists = libraryStore.playlists;
    if (playlists.isEmpty) {
      _showMessage('Create a playlist first.');
      return;
    }
    final name = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add to playlist')),
            ...playlists.keys.map((key) => ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(key),
              onTap: () => Navigator.pop(context, key),
            )),
          ],
        ),
      ),
    );
    if (name != null) {
      await libraryStore.addToPlaylist(name, song.id);
      if (mounted) _showMessage('Added to $name');
    }
  }

  Future<void> _deletePlaylist(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('Delete "$name"? Songs will remain in your music library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await libraryStore.deletePlaylist(name);
      if (mounted) setState(() {});
    }
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepMinutes = minutes == 0 ? null : minutes;
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () async {
        await audioPlayer.pause();
        if (mounted) {
          setState(() => _sleepMinutes = null);
          _showMessage('Sleep timer ended. Playback paused.');
        }
      });
    }
    setState(() {});
    _showMessage(minutes == 0 ? 'Sleep timer turned off.' : 'Sleep timer set for $minutes minutes.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) return _permissionScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VibePlay', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Rescan music', onPressed: _scan, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            tooltip: 'Sort songs',
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => ['Title', 'Artist', 'Date Added']
                .map((value) => PopupMenuItem(value: value, child: Text('Sort by $value')))
                .toList(),
          ),
          PopupMenuButton<int>(
            tooltip: 'Sleep timer',
            icon: const Icon(Icons.timer_outlined),
            onSelected: _setSleepTimer,
            itemBuilder: (_) => [0, 15, 30, 60].map((minutes) => PopupMenuItem(
              value: minutes,
              child: Text(minutes == 0 ? 'Sleep timer off' : '$minutes minutes'),
            )).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search title, artist or album',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              children: [
                Text(_scanning ? 'Scanning your music...' : '${_songs.length} songs found',
                    style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                if (_sleepMinutes != null)
                  Text('Sleep: ${_sleepMinutes}m', style: const TextStyle(color: Color(0xFF1DB954))),
              ],
            ),
          ),
          if (_scanning) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _tab == LibraryTab.playlists ? _playlistView() : _songList()),
          _miniPlayer(),
          NavigationBar(
            selectedIndex: LibraryTab.values.indexOf(_tab),
            onDestinationSelected: (index) => setState(() => _tab = LibraryTab.values[index]),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.music_note), label: 'Songs'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Favourites'),
              NavigationDestination(icon: Icon(Icons.queue_music), label: 'Playlists'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionScreen() => Scaffold(
    appBar: AppBar(title: const Text('VibePlay')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music, size: 76, color: Color(0xFF1DB954)),
            const SizedBox(height: 22),
            const Text('Permission needed to find your music',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text('VibePlay needs access to audio files stored on this device. Your music stays on your phone.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _permissionPermanentlyDenied ? _native.openAppSettings : _grantPermission,
              icon: const Icon(Icons.lock_open),
              label: Text(_permissionPermanentlyDenied ? 'Open App Settings' : 'Grant Permission'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _songList() {
    final songs = _filteredSongs;
    if (songs.isEmpty && !_scanning) {
      return Center(
        child: Text(
          _tab == LibraryTab.favourites
              ? 'No favourites yet. Tap the heart while a song is playing.'
              : _search.text.isNotEmpty ? 'No matching songs found.' : 'No music found. Tap refresh to scan again.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: AlbumArt(albumId: song.albumId),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(song.duration, style: const TextStyle(color: Colors.white54)),
          onTap: () => _playSong(song),
          onLongPress: () => _addToPlaylist(song),
        );
      },
    );
  }

  Widget _playlistView() {
    final playlists = libraryStore.playlists;
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music, size: 54, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Create your first playlist', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _createPlaylist, icon: const Icon(Icons.add), label: const Text('Create playlist')),
          ],
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: FilledButton.icon(onPressed: _createPlaylist, icon: const Icon(Icons.add), label: const Text('Create playlist')),
        ),
        ...playlists.entries.map((entry) {
          final playlistSongs = entry.value
              .map((id) {
                for (final song in _songs) {
                  if (song.id == id) return song;
                }
                return null;
              })
              .whereType<Song>()
              .toList();
          return ExpansionTile(
            leading: const Icon(Icons.queue_music, color: Color(0xFF1DB954)),
            title: Text(entry.key),
            subtitle: Text('${playlistSongs.length} songs'),
            trailing: IconButton(
              tooltip: 'Delete playlist',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deletePlaylist(entry.key),
            ),
            children: playlistSongs.isEmpty
                ? [const ListTile(title: Text('No songs in this playlist', style: TextStyle(color: Colors.white54)))]
                : playlistSongs.map((song) => ListTile(
                    leading: AlbumArt(albumId: song.albumId, size: 42),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    trailing: IconButton(
                      tooltip: 'Remove from playlist',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () async {
                        await libraryStore.removeFromPlaylist(entry.key, song.id);
                        if (mounted) setState(() {});
                      },
                    ),
                    onTap: () => _playSong(song),
                  )).toList(),
          );
        }),
      ],
    );
  }

  Widget _miniPlayer() {
    return StreamBuilder<SequenceState?>(
      stream: audioPlayer.sequenceStateStream,
      builder: (context, snapshot) {
        final index = snapshot.data?.currentIndex;
        if (index == null || index < 0 || index >= _songs.length) return const SizedBox.shrink();
        final song = _songs[index];
        return Material(
          color: const Color(0xFF1E1E1E),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PlayerScreen(songs: _songs),
            )),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  AlbumArt(albumId: song.albumId, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: audioPlayer.hasPrevious ? audioPlayer.seekToPrevious : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: audioPlayer.playerStateStream,
                    builder: (context, state) => IconButton(
                      tooltip: audioPlayer.playing ? 'Pause' : 'Play',
                      onPressed: () => audioPlayer.playing ? audioPlayer.pause() : audioPlayer.play(),
                      icon: Icon(audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                          color: const Color(0xFF1DB954)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: audioPlayer.hasNext ? audioPlayer.seekToNext : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

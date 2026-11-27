import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/playlist.dart';

/// Local database (Hive) for favourites and playlists. Works fully offline.
class StorageService extends ChangeNotifier {
  StorageService._(this._favourites, this._playlists);

  final Box<dynamic> _favourites;
  final Box<dynamic> _playlists;

  static Future<StorageService> create() async {
    await Hive.initFlutter();
    final Box<dynamic> favourites = await Hive.openBox<dynamic>('favourites');
    final Box<dynamic> playlists = await Hive.openBox<dynamic>('playlists');
    return StorageService._(favourites, playlists);
  }

  // ---------------------------------------------------------------- favourites

  bool isFavourite(int songId) => _favourites.containsKey(songId.toString());

  /// Favourite song ids, most recently added first.
  List<int> get favouriteIdsOrdered {
    final List<MapEntry<dynamic, dynamic>> entries = _favourites.toMap().entries.toList();
    entries.sort((MapEntry<dynamic, dynamic> a, MapEntry<dynamic, dynamic> b) {
      final int av = a.value is num ? (a.value as num).toInt() : 0;
      final int bv = b.value is num ? (b.value as num).toInt() : 0;
      return bv.compareTo(av);
    });
    final List<int> ids = <int>[];
    for (final MapEntry<dynamic, dynamic> entry in entries) {
      final int? id = int.tryParse(entry.key.toString());
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<void> toggleFavourite(int songId) async {
    final String key = songId.toString();
    if (_favourites.containsKey(key)) {
      await _favourites.delete(key);
    } else {
      await _favourites.put(key, DateTime.now().millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- playlists

  List<Playlist> get playlists {
    final List<Playlist> result = <Playlist>[];
    for (final dynamic key in _playlists.keys) {
      final dynamic raw = _playlists.get(key);
      if (raw is Map) {
        try {
          result.add(Playlist.fromMap(raw));
        } catch (_) {
          // Skip corrupted entries instead of crashing the UI.
        }
      }
    }
    result.sort((Playlist a, Playlist b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Playlist? playlistById(String id) {
    final dynamic raw = _playlists.get(id);
    if (raw is Map) {
      try {
        return Playlist.fromMap(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<Playlist> createPlaylist(String name) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Playlist playlist = Playlist(
      id: now.toString(),
      name: name.trim(),
      songIds: <int>[],
      createdAt: now,
    );
    await _playlists.put(playlist.id, playlist.toMap());
    notifyListeners();
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _playlists.delete(playlistId);
    notifyListeners();
  }

  /// Returns false when the song was already in the playlist.
  Future<bool> addSongToPlaylist(String playlistId, int songId) async {
    final Playlist? playlist = playlistById(playlistId);
    if (playlist == null) return false;
    if (playlist.songIds.contains(songId)) return false;
    final List<int> updated = <int>[...playlist.songIds, songId];
    await _playlists.put(
      playlistId,
      Playlist(
        id: playlist.id,
        name: playlist.name,
        songIds: updated,
        createdAt: playlist.createdAt,
      ).toMap(),
    );
    notifyListeners();
    return true;
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    final Playlist? playlist = playlistById(playlistId);
    if (playlist == null) return;
    final List<int> updated = playlist.songIds.where((int id) => id != songId).toList();
    await _playlists.put(
      playlistId,
      Playlist(
        id: playlist.id,
        name: playlist.name,
        songIds: updated,
        createdAt: playlist.createdAt,
      ).toMap(),
    );
    notifyListeners();
  }
}

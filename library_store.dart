import 'package:hive/hive.dart';

class LibraryStore {
  static const _boxName = 'vibeplay_library';
  late Box<dynamic> _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Set<int> get favourites =>
      Set<int>.from((_box.get('favourites', defaultValue: <int>[]) as List).cast<int>());

  bool isFavourite(int id) => favourites.contains(id);

  Future<void> toggleFavourite(int id) async {
    final updated = favourites;
    if (!updated.add(id)) updated.remove(id);
    await _box.put('favourites', updated.toList());
  }

  Map<String, List<int>> get playlists {
    final raw = Map<String, dynamic>.from(
      _box.get('playlists', defaultValue: <String, dynamic>{}) as Map,
    );
    return raw.map((key, value) => MapEntry(key, List<int>.from(value as List)));
  }

  Future<void> createPlaylist(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final current = playlists;
    if (current.containsKey(normalized)) {
      throw StateError('A playlist with that name already exists.');
    }
    current[normalized] = <int>[];
    await _box.put('playlists', current);
  }

  Future<void> deletePlaylist(String name) async {
    final current = playlists..remove(name);
    await _box.put('playlists', current);
  }

  Future<void> addToPlaylist(String name, int songId) async {
    final current = playlists;
    final items = current[name];
    if (items == null) return;
    if (!items.contains(songId)) items.add(songId);
    current[name] = items;
    await _box.put('playlists', current);
  }

  Future<void> removeFromPlaylist(String name, int songId) async {
    final current = playlists;
    current[name]?.remove(songId);
    await _box.put('playlists', current);
  }
}

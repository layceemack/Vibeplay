import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'media_store_service.dart';

enum SortMode { title, artist, dateAdded }

String sortLabel(SortMode mode) {
  switch (mode) {
    case SortMode.title:
      return 'Title';
    case SortMode.artist:
      return 'Artist';
    case SortMode.dateAdded:
      return 'Date added';
  }
}

/// Scans the device with MediaStore and exposes the (searchable, sortable) song list.
class LibraryService extends ChangeNotifier {
  final MediaStoreService _store = MediaStoreService();

  List<Song> _all = <Song>[];
  List<Song> _visible = <Song>[];
  Map<int, Song> _byId = <int, Song>{};

  bool _scanning = false;
  bool _hasScanned = false;
  String? _error;
  String _query = '';
  SortMode _sort = SortMode.title;

  List<Song> get songs => _visible;
  List<Song> get allSongs => _all;
  int get totalCount => _all.length;
  bool get isScanning => _scanning;
  bool get hasScanned => _hasScanned;
  String? get error => _error;
  String get query => _query;
  SortMode get sortMode => _sort;

  Song? byId(int id) => _byId[id];

  /// Reads songs from MediaStore. With [deep] true the whole storage is walked first
  /// so brand-new files that Android has not indexed yet are picked up too.
  Future<void> scan({bool deep = false}) async {
    if (_scanning) return;
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      if (deep) {
        await _store.scanStorage();
      }
      List<Song> found = await _store.querySongs();
      if (found.isEmpty && !deep) {
        await _store.scanStorage();
        found = await _store.querySongs();
      }
      _all = found;
      _byId = <int, Song>{for (final Song s in found) s.id: s};
      _hasScanned = true;
    } catch (e) {
      debugPrint('Scan failed: $e');
      _error = 'Could not scan your music';
    }

    _scanning = false;
    _applyFilters();
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    _applyFilters();
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sort = mode;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    final String q = _query.trim().toLowerCase();
    final List<Song> result = q.isEmpty
        ? List<Song>.from(_all)
        : _all.where((Song s) => s.titleLower.contains(q) || s.artistLower.contains(q)).toList();

    switch (_sort) {
      case SortMode.title:
        result.sort((Song a, Song b) => a.titleLower.compareTo(b.titleLower));
        break;
      case SortMode.artist:
        result.sort((Song a, Song b) {
          final int byArtist = a.artistLower.compareTo(b.artistLower);
          return byArtist != 0 ? byArtist : a.titleLower.compareTo(b.titleLower);
        });
        break;
      case SortMode.dateAdded:
        result.sort((Song a, Song b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }
    _visible = result;
  }
}

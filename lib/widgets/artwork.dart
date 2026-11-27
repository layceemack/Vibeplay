import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/media_store_service.dart';
import '../theme/app_theme.dart';

/// Small in-memory cache so list scrolling does not reload artwork over and over.
class ArtworkCache {
  ArtworkCache._();

  static final ArtworkCache instance = ArtworkCache._();

  final MediaStoreService _store = MediaStoreService();
  final Map<String, Uint8List?> _cache = <String, Uint8List?>{};
  final Map<String, Future<Uint8List?>> _pending = <String, Future<Uint8List?>>{};
  static const int _maxEntries = 400;

  Future<Uint8List?> load(Song song, int pixelSize) {
    final String key = '${song.id}_$pixelSize';

    if (_cache.containsKey(key)) {
      final Uint8List? value = _cache.remove(key);
      _cache[key] = value; // move to the "most recent" end
      return SynchronousFuture<Uint8List?>(value);
    }

    return _pending.putIfAbsent(key, () async {
      final Uint8List? bytes = await _store.getArtwork(song.id, song.albumId, pixelSize);
      _cache[key] = bytes;
      if (_cache.length > _maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      _pending.remove(key);
      return bytes;
    });
  }
}

/// Album artwork from MediaStore, with a music-note placeholder.
class Artwork extends StatefulWidget {
  const Artwork({
    super.key,
    required this.song,
    this.size = 52,
    this.radius = 8,
    this.pixelSize = 160,
  });

  final Song? song;
  final double size;
  final double radius;
  final int pixelSize;

  @override
  State<Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<Artwork> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id || oldWidget.pixelSize != widget.pixelSize) {
      _refresh();
    }
  }

  void _refresh() {
    final Song? song = widget.song;
    _future = song == null ? null : ArtworkCache.instance.load(song, widget.pixelSize);
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.cardHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.textSecondary,
        size: widget.size * 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<Uint8List?>? future = _future;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: future == null
            ? _placeholder()
            : FutureBuilder<Uint8List?>(
                future: future,
                builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
                  final Uint8List? data = snapshot.data;
                  if (data != null) {
                    return Image.memory(
                      data,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      width: widget.size,
                      height: widget.size,
                    );
                  }
                  return _placeholder();
                },
              ),
      ),
    );
  }
}

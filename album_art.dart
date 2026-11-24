import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/native_music_service.dart';

final NativeMusicService _artService = NativeMusicService();
final Map<int, Future<Uint8List?>> _artCache = {};

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.albumId,
    this.size = 52,
    this.radius = 9,
  });

  final int albumId;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final future = _artCache.putIfAbsent(albumId, () => _artService.getAlbumArtwork(albumId));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder());
            }
            return _placeholder();
          },
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF292929),
        alignment: Alignment.center,
        child: const Icon(Icons.album, color: Color(0xFF1DB954)),
      );
}

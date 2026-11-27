import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/song.dart';

/// Bridge to the native Kotlin code in MainActivity.kt.
/// Reads songs straight from Android's MediaStore - no file picker involved.
class MediaStoreService {
  static const MethodChannel _channel = MethodChannel('vibeplay/media');

  Future<int> getSdkInt() async {
    try {
      final int? sdk = await _channel.invokeMethod<int>('getSdkInt');
      return sdk ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Asks Android's media scanner to index audio files that MediaStore does not know yet.
  Future<int> scanStorage() async {
    final int? count = await _channel.invokeMethod<int>('scanStorage');
    return count ?? 0;
  }

  /// Returns every .mp3 / .m4a / .wav / .aac / .flac file known to MediaStore.
  Future<List<Song>> querySongs() async {
    final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>('querySongs');
    if (raw == null) return <Song>[];
    return raw
        .map((dynamic e) => Song.fromMap(Map<dynamic, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList();
  }

  /// JPEG bytes of the album artwork, or null when the song has none.
  Future<Uint8List?> getArtwork(int id, int albumId, int size) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getArtwork', <String, dynamic>{
        'id': id,
        'albumId': albumId,
        'size': size,
      });
    } catch (_) {
      return null;
    }
  }
}

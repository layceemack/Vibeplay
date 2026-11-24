import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/song.dart';

class PermissionState {
  const PermissionState({
    required this.granted,
    required this.permanentlyDenied,
  });
  final bool granted;
  final bool permanentlyDenied;

  factory PermissionState.fromMap(Map<dynamic, dynamic> map) => PermissionState(
        granted: map['granted'] == true,
        permanentlyDenied: map['permanentlyDenied'] == true,
      );
}

class NativeMusicService {
  static const _channel = MethodChannel('com.vibeplay/native_music');

  Future<PermissionState> requestAudioPermission() async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>('requestAudioPermission');
    return PermissionState.fromMap(result ?? const {});
  }

  Future<bool> hasAudioPermission() async =>
      await _channel.invokeMethod<bool>('hasAudioPermission') ?? false;

  Future<void> requestNotificationPermission() async {
    await _channel.invokeMethod<void>('requestNotificationPermission');
  }

  Future<void> openAppSettings() async {
    await _channel.invokeMethod<void>('openAppSettings');
  }

  Future<List<Song>> scanAudio() async {
    final result = await _channel.invokeListMethod<dynamic>('scanAudio') ?? const [];
    return result
        .map((row) => Song.fromMap(Map<dynamic, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<Uint8List?> getAlbumArtwork(int albumId) async {
    if (albumId < 0) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('getAlbumArtwork', {'albumId': albumId});
    } on PlatformException {
      return null;
    }
  }
}

/// A song found in Android's MediaStore.
class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.durationMs,
    required this.dateAdded,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final int durationMs;

  /// Seconds since epoch (MediaStore DATE_ADDED).
  final int dateAdded;

  late final String titleLower = title.toLowerCase();
  late final String artistLower = artist.toLowerCase();

  /// content:// URI used by the audio player.
  String get uri => 'content://media/external/audio/media/$id';

  /// content:// URI of the album artwork (used for the media notification).
  String get albumArtUri => 'content://media/external/audio/albumart/$albumId';

  factory Song.fromMap(Map<dynamic, dynamic> map) {
    String text(dynamic value, String fallback) {
      final String s = value is String ? value.trim() : '';
      return s.isEmpty ? fallback : s;
    }

    int number(dynamic value) => value is num ? value.toInt() : 0;

    return Song(
      id: number(map['id']),
      title: text(map['title'], 'Unknown title'),
      artist: text(map['artist'], 'Unknown Artist'),
      album: text(map['album'], 'Unknown Album'),
      albumId: number(map['albumId']),
      durationMs: number(map['duration']),
      dateAdded: number(map['dateAdded']),
    );
  }
}

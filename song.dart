class Song {
  const Song({
    required this.id,
    required this.albumId,
    required this.title,
    required this.artist,
    required this.album,
    required this.uri,
    required this.durationMs,
    required this.dateAdded,
  });

  final int id;
  final int albumId;
  final String title;
  final String artist;
  final String album;
  final String uri;
  final int durationMs;
  final int dateAdded;

  factory Song.fromMap(Map<dynamic, dynamic> map) => Song(
        id: (map['id'] as num).toInt(),
        albumId: (map['albumId'] as num?)?.toInt() ?? -1,
        title: _clean(map['title'], 'Unknown title'),
        artist: _clean(map['artist'], 'Unknown artist'),
        album: _clean(map['album'], 'Unknown album'),
        uri: map['uri'].toString(),
        durationMs: (map['duration'] as num?)?.toInt() ?? 0,
        dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      );

  static String _clean(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == '<unknown>' ? fallback : text;
  }

  String get duration {
    final seconds = durationMs ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

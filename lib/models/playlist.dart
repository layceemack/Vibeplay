/// A user-created playlist stored in the local Hive database.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<int> songIds;
  final int createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAt': createdAt,
      };

  factory Playlist.fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> rawIds = (map['songIds'] as List<dynamic>?) ?? <dynamic>[];
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      songIds: rawIds.map((dynamic e) => (e as num).toInt()).toList(),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

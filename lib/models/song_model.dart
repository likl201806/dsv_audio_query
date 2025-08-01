import 'dart:typed_data';

/// Represents a single song's metadata.
class SongModel {
  /// The unique ID of the song on the device.
  /// On Android, this is the `_ID` from MediaStore.
  /// On iOS, this is the `persistentID` from MPMediaItem.
  final int id;

  /// The title of the song.
  final String title;

  /// The artist of the song. Can be null if not available.
  final String? artist;

  /// The album the song belongs to. Can be null if not available.
  final String? album;

  /// The duration of the song in milliseconds. Can be null if not available.
  final int? duration;

  /// The absolute file path to the song on the device.
  final String data;

  /// The artwork of the song as a byte array. Can be null if not available.
  final Uint8List? artwork;

  /// Creates a new instance of [SongModel].
  SongModel({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    required this.data,
    this.artwork,
  });

  /// Creates a [SongModel] instance from a [Map] (typically from the platform channel).
  factory SongModel.fromMap(Map<dynamic, dynamic> map) {
    return SongModel(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      duration: map['duration'],
      data: map['data'],
      artwork: map['artwork'],
    );
  }

  /// Converts the [SongModel] instance to a [Map].
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'data': data,
      'artwork': artwork,
    };
  }
}

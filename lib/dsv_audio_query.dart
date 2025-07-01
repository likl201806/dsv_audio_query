import 'dsv_audio_query_platform_interface.dart';
import 'models/permission_status.dart';
import 'models/song_model.dart';

export 'models/permission_status.dart';
export 'models/song_model.dart';

/// A Flutter plugin to query audio files from device storage.
class DsvAudioQuery {
  /// Fetches the platform version.
  ///
  /// This is a sample method and can be removed.
  Future<String?> getPlatformVersion() {
    return DsvAudioQueryPlatform.instance.getPlatformVersion();
  }

  /// Requests permission to access the media library.
  /// Returns a [PermissionStatus] indicating the result.
  Future<PermissionStatus> requestPermission() {
    return DsvAudioQueryPlatform.instance.requestPermission();
  }

  /// Queries for songs available on the device.
  ///
  /// Returns a [List] of [SongModel] objects.
  /// The [sortType] parameter can be used to define the order (not yet implemented).
  /// Throws a [PlatformException] if the query fails on the native side.
  Future<List<SongModel>> querySongs({String? sortType}) {
    return DsvAudioQueryPlatform.instance.querySongs(sortType: sortType);
  }

  Future<void> scanFile({String? path}) {
    return DsvAudioQueryPlatform.instance.scanFile(path: path);
  }
}

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dsv_audio_query_method_channel.dart';
import 'models/permission_status.dart';
import 'models/song_model.dart';

export 'models/permission_status.dart';
export 'models/song_model.dart';

abstract class DsvAudioQueryPlatform extends PlatformInterface {
  /// Constructs a DsvAudioQueryPlatform.
  DsvAudioQueryPlatform() : super(token: _token);

  static final Object _token = Object();

  static DsvAudioQueryPlatform _instance = MethodChannelDsvAudioQuery();

  /// The default instance of [DsvAudioQueryPlatform] to use.
  ///
  /// Defaults to [MethodChannelDsvAudioQuery].
  static DsvAudioQueryPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DsvAudioQueryPlatform] when
  /// they register themselves.
  static set instance(DsvAudioQueryPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// A sample method.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Requests permission to access the media library.
  /// Returns a [PermissionStatus] indicating the result.
  Future<PermissionStatus> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// The method to query songs from the platform.
  Future<List<SongModel>> querySongs({String? sortType}) {
    throw UnimplementedError('querySongs() has not been implemented.');
  }

  /// Deletes a song and its MediaStore entry.
  Future<bool> deleteSong({required SongModel song}) {
    throw UnimplementedError('deleteSong() has not been implemented.');
  }

  /// Scans a file to make it available to the media library.
  /// On Android, this triggers the MediaScanner. If path is null, it scans the public Music directory.
  /// On iOS, this is a no-op as files in the Documents directory are found automatically.
  Future<void> scanFile({String? path}) {
    throw UnimplementedError('scanFile() has not been implemented.');
  }
}

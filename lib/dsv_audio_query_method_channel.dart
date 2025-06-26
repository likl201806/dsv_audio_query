import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dsv_audio_query_platform_interface.dart';
import 'models/song_model.dart';

/// An implementation of [DsvAudioQueryPlatform] that uses method channels.
class MethodChannelDsvAudioQuery extends DsvAudioQueryPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dsv_audio_query');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    try {
      final int? status =
          await methodChannel.invokeMethod<int>('requestPermission');
      return PermissionStatus.values[status ?? PermissionStatus.denied.index];
    } on PlatformException {
      return PermissionStatus.permanentlyDenied;
    }
  }

  @override
  Future<List<SongModel>> querySongs({String? sortType}) async {
    try {
      final List<dynamic>? result =
          await methodChannel.invokeMethod<List<dynamic>>(
        'querySongs',
        {'sortType': sortType},
      );

      if (result == null) {
        return [];
      }

      return result.map((e) => SongModel.fromMap(e)).toList();
    } on PlatformException catch (e) {
      // Handle native code exceptions.
      debugPrint("Failed to query songs: '${e.message}'.");
      return [];
    }
  }
}

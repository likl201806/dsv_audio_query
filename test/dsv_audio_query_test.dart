import 'package:flutter_test/flutter_test.dart';
import 'package:dsv_audio_query/dsv_audio_query.dart';
import 'package:dsv_audio_query/dsv_audio_query_platform_interface.dart';
import 'package:dsv_audio_query/dsv_audio_query_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDsvAudioQueryPlatform
    with MockPlatformInterfaceMixin
    implements DsvAudioQueryPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<List<SongModel>> querySongs({String? sortType}) async {
    return [];
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    return PermissionStatus.granted;
  }

  @override
  Future<void> scanFile({String? path}) async {
    // This is a mock, so we don't need to do anything.
  }
}

void main() {
  final DsvAudioQueryPlatform initialPlatform = DsvAudioQueryPlatform.instance;

  test('$MethodChannelDsvAudioQuery is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDsvAudioQuery>());
  });

  test('querySongs returns empty list', () async {
    DsvAudioQuery dsvAudioQueryPlugin = DsvAudioQuery();
    MockDsvAudioQueryPlatform fakePlatform = MockDsvAudioQueryPlatform();
    DsvAudioQueryPlatform.instance = fakePlatform;

    expect(await dsvAudioQueryPlugin.querySongs(), []);
  });

  test('getPlatformVersion', () async {
    DsvAudioQuery dsvAudioQueryPlugin = DsvAudioQuery();
    MockDsvAudioQueryPlatform fakePlatform = MockDsvAudioQueryPlatform();
    DsvAudioQueryPlatform.instance = fakePlatform;

    expect(await dsvAudioQueryPlugin.getPlatformVersion(), '42');
  });
}

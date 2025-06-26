# dsv_audio_query

[![pub version](https://img.shields.io/pub/v/dsv_audio_query.svg)](https://pub.dev/packages/dsv_audio_query)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin to query audio files from the device's media library on both Android and iOS platforms.

## Features

- Query songs from the device.
- Get detailed information for each song (ID, title, artist, album, duration, file path).
- Written in Kotlin for Android and Swift for iOS.

## Supported Platforms

- **Android** (API 21+)
- **iOS** (iOS 10.0+)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dsv_audio_query: ^0.0.1 # Replace with the latest version
```

Then run `flutter pub get`.

## Native Platform Configuration

### Android

You need to add permissions to your `android/app/src/main/AndroidManifest.xml`. For Android 13 (API 33) and above, you need `READ_MEDIA_AUDIO`. For backwards compatibility, also include `READ_EXTERNAL_STORAGE`.

```xml
<manifest>
    ...
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    ...
</manifest>
```

### iOS

You need to add a usage description to your `ios/Runner/Info.plist` file for accessing the user's media library.

```xml
<key>NSAppleMusicUsageDescription</key>
<string>Our app needs access to your music library to play songs.</string>
```

## Usage

Here's a simple example of how to query songs.

```dart
import 'package:dsv_audio_query/dsv_audio_query.dart';
import 'package:flutter/material.dart';

class SongListScreen extends StatefulWidget {
  @override
  _SongListScreenState createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  final DsvAudioQuery _audioQuery = DsvAudioQuery();
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    // TODO: Add permission request logic here before querying.
    // For now, we assume permissions are granted.

    final songs = await _audioQuery.querySongs();
    setState(() {
      _songs = songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Songs'),
      ),
      body: _songs.isEmpty
          ? Center(child: Text('No songs found.'))
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  title: Text(song.title),
                  subtitle: Text(song.artist ?? 'Unknown Artist'),
                  trailing: Text('${song.duration} ms'),
                );
              },
            ),
    );
  }
}
```

## API Overview

- `DsvAudioQuery()`: The main class for all query operations.
- `querySongs({String? sortType})`: Fetches a list of `SongModel` from the device.
- `SongModel`: A class representing a single audio file with its metadata.

---

This project is a starting point for a Flutter plugin. Contributions are welcome!

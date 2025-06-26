import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:dsv_audio_query/dsv_audio_query.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<SongModel> _songs = [];
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  final _dsvAudioQueryPlugin = DsvAudioQuery();
  final _audioPlayer = AudioPlayer();
  int? _currentlyPlayingSongId;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> requestPermission() async {
    final status = await _dsvAudioQueryPlugin.requestPermission();
    setState(() => _permissionStatus = status);
    if (status == PermissionStatus.granted) {
      querySongs();
    }
  }

  Future<void> querySongs() async {
    if (_permissionStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Permission not granted.'),
        action: SnackBarAction(label: 'Request', onPressed: requestPermission),
      ));
      return;
    }

    List<SongModel> songs;
    try {
      songs = await _dsvAudioQueryPlugin.querySongs();
    } on PlatformException {
      songs = <SongModel>[];
      debugPrint('Failed to get songs.');
    }

    if (!mounted) return;
    setState(() => _songs = songs);
  }

  Future<void> _playSong(SongModel song) async {
    try {
      if (_audioPlayer.playing && _currentlyPlayingSongId == song.id) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingSongId = null);
      } else {
        await _audioPlayer.setUrl(song.data);
        _audioPlayer.play();
        setState(() => _currentlyPlayingSongId = song.id);
      }
    } catch (e) {
      debugPrint("Error playing song: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play song: ${song.title}')),
      );
    }
  }

  void _showSongDetailsDialog(SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.title),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              _buildDetailRow('Artist', song.artist ?? 'N/A'),
              _buildDetailRow('Album', song.album ?? 'N/A'),
              _buildDetailRow('Duration', '${(song.duration ?? 0) ~/ 1000}s'),
              _buildDetailRow('ID', song.id.toString()),
              _buildDetailRow('Path', song.data),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: <TextSpan>[
            TextSpan(
                text: '$title: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_permissionStatus) {
      case PermissionStatus.granted:
        body = _songs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No songs found.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: querySongs,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: querySongs,
                child: ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isPlaying = song.id == _currentlyPlayingSongId;
                    return ListTile(
                      leading: isPlaying
                          ? const Icon(Icons.pause_circle_filled,
                              color: Colors.blue)
                          : const Icon(Icons.play_circle_fill),
                      title: Text(song.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist ?? 'Unknown Artist',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(song.duration ?? 0) ~/ 1000} s'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _showSongDetailsDialog(song),
                          ),
                        ],
                      ),
                      onTap: () => _playSong(song),
                    );
                  },
                ),
              );
        break;
      case PermissionStatus.denied:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Permission Denied.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: requestPermission,
                child: const Text('Request Permission'),
              ),
            ],
          ),
        );
        break;
      case PermissionStatus.permanentlyDenied:
        body = const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Permission permanently denied. Please open app settings to grant media library access.',
              textAlign: TextAlign.center,
            ),
          ),
        );
        break;
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('dsv_audio_query example'),
        ),
        body: body,
      ),
    );
  }
}

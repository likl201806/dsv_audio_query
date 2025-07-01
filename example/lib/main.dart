import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dsv_audio_query/models/song_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:dsv_audio_query/dsv_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dsv_audio_query example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Platform.isIOS ? const DownloadScreen() : const LocalSongsScreen(),
    );
  }
}

class DownloadableSong {
  final String title;
  final String artist;
  final String url;
  DownloadableSong(
      {required this.title, required this.artist, required this.url});
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final List<DownloadableSong> _downloadableSongs = [
    DownloadableSong(
      title: 'The Podcast Intro',
      artist: 'Music by Scott Buckley',
      url: 'https://cdn1.suno.ai/ea8b2541-6df4-4619-8afa-8ec88ecb92eb.mp3',
    ),
    DownloadableSong(
      title: 'Titan',
      artist: 'Music by Scott Buckley',
      url: 'https://cdn1.suno.ai/5f237e8a-c49c-402d-873d-234b41cbe9bf.mp3',
    ),
    DownloadableSong(
        title: 'Affirmations',
        artist: 'Music by Scott Buckley',
        url: 'https://cdn1.suno.ai/68a8216b-57f2-45f5-9071-6a42fd858506.mp3'),
  ];

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloaded = {};
  final Dio _dio = Dio();
  final _dsvAudioQueryPlugin = DsvAudioQuery();
  late final String _localPath;

  @override
  void initState() {
    super.initState();
    _prepareStorage();
  }

  Future<void> _prepareStorage() async {
    final directory = await getApplicationDocumentsDirectory();
    _localPath = directory.path;
    _checkExistingFiles();
  }

  void _checkExistingFiles() {
    for (var song in _downloadableSongs) {
      final fileName = song.url.split('/').last;
      final file = File('$_localPath/$fileName');
      if (file.existsSync()) {
        setState(() {
          _isDownloaded[song.url] = true;
        });
      }
    }
  }

  Future<void> _downloadSong(DownloadableSong song) async {
    if (_isDownloaded[song.url] == true) return;

    final fileName = song.url.split('/').last;
    final savePath = '$_localPath/$fileName';

    setState(() {
      _downloadProgress[song.url] = 0.0;
    });

    try {
      await _dio.download(
        song.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[song.url] = received / total;
            });
          }
        },
      );
      setState(() {
        _isDownloaded[song.url] = true;
        _downloadProgress.remove(song.url);
      });
      // After successful download, scan the file to make it visible to MediaStore on Android.
      if (Platform.isAndroid) {
        await _dsvAudioQueryPlugin.scanFile(path: savePath);
      }
    } catch (e) {
      debugPrint("Error downloading song: $e");
      setState(() {
        _downloadProgress.remove(song.url);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download ${song.title}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Songs for Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _downloadableSongs.length,
              itemBuilder: (context, index) {
                final song = _downloadableSongs[index];
                final progress = _downloadProgress[song.url];
                final isDownloaded = _isDownloaded[song.url] == true;

                return ListTile(
                  title: Text(song.title),
                  subtitle: Text(song.artist),
                  trailing: isDownloaded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : progress != null
                          ? CircularProgressIndicator(value: progress)
                          : IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _downloadSong(song),
                            ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LocalSongsScreen(),
                ));
              },
              child: const Text('Go to Local Music Library'),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalSongsScreen extends StatefulWidget {
  const LocalSongsScreen({super.key});

  @override
  State<LocalSongsScreen> createState() => _LocalSongsScreenState();
}

class _LocalSongsScreenState extends State<LocalSongsScreen> {
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

  Future<void> _refreshSongs() async {
    // On Android, this will scan the public Music directory for new files.
    // On iOS, this is a no-op but harmless.
    await _dsvAudioQueryPlugin.scanFile();
    await querySongs();
  }

  Future<void> querySongs() async {
    // On iOS, songs are queried from the app's documents directory where they were downloaded.
    // On Android, it queries the shared media store.
    if (_permissionStatus != PermissionStatus.granted && !Platform.isIOS) {
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
        // For iOS, the path from the plugin is a full path.
        // For Android, it's a content URI. `just_audio` handles both.
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
              if (song.artwork != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.memory(song.artwork!),
                  ),
                ),
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

    // On iOS, we assume permission to read from our own directory is implicitly granted.
    if (Platform.isIOS && _permissionStatus == PermissionStatus.denied) {
      _permissionStatus = PermissionStatus.granted;
      querySongs();
    }

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
                onRefresh: _refreshSongs,
                child: ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isPlaying = song.id == _currentlyPlayingSongId;
                    return ListTile(
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (song.artwork != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.0),
                                child: Image.memory(
                                  song.artwork!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.music_note,
                                        size: 30, color: Colors.grey);
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Icon(Icons.music_note,
                                    size: 30, color: Colors.grey),
                              ),
                            if (isPlaying)
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Icon(Icons.pause,
                                    color: Colors.white),
                              ),
                          ],
                        ),
                      ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Music Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSongs,
          ),
        ],
      ),
      body: body,
    );
  }
}

import Flutter
import UIKit
import MediaPlayer
import AVFoundation

public class DsvAudioQueryPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dsv_audio_query", binaryMessenger: registrar.messenger())
    let instance = DsvAudioQueryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      MPMediaLibrary.requestAuthorization { status in
        switch status {
        case .authorized:
          result(0) // granted
        case .denied:
          result(1) // denied
        case .restricted, .notDetermined:
          result(2) // permanentlyDenied
        @unknown default:
          result(2) // permanentlyDenied
        }
      }
    case "querySongs":
        // On iOS, we query from the app's documents directory.
        // Permission for this is implicitly granted.
        self.querySongsFromDocumentsDirectory(result: result)
    case "scanFile":
        // This is not needed on iOS as the file system is scanned directly.
        // We call result to complete the Dart Future.
        result(nil)
    case "deleteSong":
        guard let args = call.arguments as? [String: Any],
              let path = args["data"] as? String,
              let url = URL(string: path) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Song data is invalid", details: nil))
            return
        }
        self.deleteSong(at: url, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func querySongsFromDocumentsDirectory(result: @escaping FlutterResult) {
      let fileManager = FileManager.default
      guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
          result([])
          return
      }

      var songList: [[String: Any?]] = []
      let audioExtensions = ["mp3", "m4a", "wav", "flac", "aac"]

      do {
          let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)

          for url in fileURLs where audioExtensions.contains(url.pathExtension.lowercased()) {
              let asset = AVAsset(url: url)
              
              // Use a hash of the file path as a pseudo-persistent ID
              let persistentID = url.absoluteString.hash

              var title: String?
              var artist: String?
              var album: String?
              let durationInSeconds = CMTimeGetSeconds(asset.duration)
              let durationInMilliseconds = !durationInSeconds.isNaN ? Int(durationInSeconds * 1000) : 0

              // Fetch all available metadata
              let metadata = asset.metadata
              var artwork: Data?

              for item in metadata {
                  if item.commonKey == .commonKeyTitle {
                      title = item.stringValue
                  } else if item.commonKey == .commonKeyArtist {
                      artist = item.stringValue
                  } else if item.commonKey == .commonKeyAlbumName {
                      album = item.stringValue
                  } else if item.commonKey == .commonKeyArtwork, let dataValue = item.dataValue {
                      artwork = dataValue
                  }
              }
              
              // Fallback to filename if title is not found in metadata
              if title == nil || title!.isEmpty {
                  title = url.deletingPathExtension().lastPathComponent
              }

              let songData: [String: Any?] = [
                  "id": persistentID,
                  "title": title,
                  "artist": artist,
                  "album": album,
                  "duration": durationInMilliseconds,
                  "data": url.absoluteString, // Use the full file URL
                  "artwork": artwork
              ]
              songList.append(songData)
          }
          result(songList)
      } catch {
          result(FlutterError(code: "IO_ERROR", message: "Failed to read documents directory.", details: error.localizedDescription))
      }
  }

  private func deleteSong(at url: URL, result: @escaping FlutterResult) {
      let fileManager = FileManager.default
      do {
          try fileManager.removeItem(at: url)
          result(true)
      } catch {
          result(FlutterError(code: "DELETE_FAILED", message: "Failed to delete song file.", details: error.localizedDescription))
      }
  }
}

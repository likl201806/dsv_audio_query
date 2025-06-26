import Flutter
import UIKit
import MediaPlayer

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
        // Check permission status before querying
        if MPMediaLibrary.authorizationStatus() == .authorized {
            self.querySongsFromLibrary(result: result)
        } else {
            // Let flutter know that permission is required
            result(FlutterError(code: "PERMISSION_DENIED", message: "User has not granted media library access.", details: nil))
        }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func querySongsFromLibrary(result: @escaping FlutterResult) {
      let songsQuery = MPMediaQuery.songs()
      guard let items = songsQuery.items else {
          result([])
          return
      }

      let songList = items.map { (item: MPMediaItem) -> [String: Any?] in
          return [
              "id": item.persistentID,
              "title": item.title,
              "artist": item.artist,
              "album": item.albumTitle,
              "duration": Int(item.playbackDuration * 1000), // convert to milliseconds
              "data": item.assetURL?.absoluteString // Note: URL can be nil
          ]
      }
      result(songList)
  }
}

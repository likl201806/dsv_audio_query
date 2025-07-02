package com.example.dsv_audio_query

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** DsvAudioQueryPlugin */
class DsvAudioQueryPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var resolver: ContentResolver
  private var activity: Activity? = null
  private var pendingResult: Result? = null
  private val permissionRequestCode = 101
  private val TAG = "DsvAudioQueryPlugin"

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dsv_audio_query")
    channel.setMethodCallHandler(this)
    resolver = flutterPluginBinding.applicationContext.contentResolver
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestPermission" -> {
        pendingResult = result
        requestPermissions()
      }
      "querySongs" -> {
        if (hasPermissions()) {
          Log.d(TAG, "Permissions granted. Calling querySongsFromMediaStore.")
          querySongsFromMediaStore(result)
        } else {
          Log.w(TAG, "Permissions denied. Cannot query songs.")
          result.error("PERMISSION_DENIED", "Storage permission is denied.", null)
        }
      }
      "scanFile" -> {
        var path = call.argument<String>("path")
        if (path == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO) {
          // If no path is provided, scan the public Music directory.
          path = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC).path
        }
        if (path != null) {
          scanFile(path, result)
        } else {
          result.success(null) // Nothing to scan
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun hasPermissions(): Boolean {
    val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      Manifest.permission.READ_MEDIA_AUDIO
    } else {
      Manifest.permission.READ_EXTERNAL_STORAGE
    }
    return ContextCompat.checkSelfPermission(activity!!, permission) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestPermissions() {
    val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      Manifest.permission.READ_MEDIA_AUDIO
    } else {
      Manifest.permission.READ_EXTERNAL_STORAGE
    }

    if (ContextCompat.checkSelfPermission(activity!!, permission) != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(activity!!, arrayOf(permission), permissionRequestCode)
    } else {
      // Permission already granted
      pendingResult?.success(0) // granted
      pendingResult = null
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    if (requestCode == permissionRequestCode) {
      if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        pendingResult?.success(0) // granted
      } else {
        if (ActivityCompat.shouldShowRequestPermissionRationale(activity!!, permissions[0])) {
          pendingResult?.success(1) // denied
        } else {
          pendingResult?.success(2) // permanently denied
        }
      }
      pendingResult = null
      return true
    }
    return false
  }

  private fun querySongsFromMediaStore(result: Result) {
    Log.d(TAG, "Starting querySongsFromMediaStore.")
    val songList = mutableListOf<Map<String, Any?>>()
    val retriever = MediaMetadataRetriever()

    // Define the columns to be queried from the Files table.
    val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DATA, // File path
        MediaStore.Files.FileColumns.TITLE
    )

    // Query condition: select files based on MIME type for common audio formats.
    val selection = "${MediaStore.Files.FileColumns.MIME_TYPE} IN (?, ?, ?, ?, ?, ?)"
    val selectionArgs = arrayOf("audio/mpeg", "audio/mp3", "audio/x-wav", "audio/ogg", "audio/x-ms-wma", "audio/flac")

    // Sort order.
    val sortOrder = "${MediaStore.Files.FileColumns.TITLE} ASC"
    Log.d(TAG, "Querying MediaStore.Files with selection: $selection")

    try {
      resolver.query(
          MediaStore.Files.getContentUri("external"),
          projection,
          null,
          null,
          null
      )?.use { cursor -> // 'use' will automatically close the cursor
        Log.d(TAG, "Query successful. Found ${cursor.count} potential audio files.")
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
        val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
        val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.TITLE)

        while (cursor.moveToNext()) {
          val filePath = cursor.getString(dataColumn)
          Log.d(TAG, "Processing file: $filePath")
          var artwork: ByteArray? = null
          var title: String? = cursor.getString(titleColumn)
          var artist: String? = null
          var album: String? = null
          var duration: Long? = null

          if (filePath != null) {
            try {
              retriever.setDataSource(filePath)
              artwork = retriever.embeddedPicture
              artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
              album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
              val fileTitle = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
              // Only use the retriever's title if the MediaStore title is null, empty, or a filename.
              if (title.isNullOrEmpty() || title == filePath.substringAfterLast('/')) {
                if (!fileTitle.isNullOrEmpty()) {
                  title = fileTitle
                }
              }
              retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.let {
                duration = it.toLongOrNull()
              }
              Log.d(TAG, "  -> Metadata: Title='$title', Artist='$artist', Duration=$duration")
            } catch (e: Exception) {
              Log.e(TAG, "  -> Failed to retrieve metadata for $filePath", e)
              // File path may be invalid, file is corrupted, or lacks metadata.
            }
          }

          // Filter out short audio clips (e.g., ringtones) and add to list
          duration?.let { currentDuration ->
            if (currentDuration >= 3000) {
                Log.d(TAG, "  -> Adding song to list: $title")
                val songMap = mapOf(
                    "id" to cursor.getLong(idColumn),
                    "title" to title,
                    "artist" to artist,
                    "album" to album,
                    "duration" to currentDuration,
                    "data" to filePath,
                    "artwork" to artwork
                )
                songList.add(songMap)
            } else {
              Log.d(TAG, "  -> Skipping short audio file: $title, Duration: $currentDuration")
            }
          }
        }
      }
      Log.d(TAG, "Query finished. Returning ${songList.size} songs.")
      result.success(songList)
    } catch (e: Exception) {
      Log.e(TAG, "QUERY_FAILED", e)
      result.error("QUERY_FAILED", e.message, null)
    } finally {
        retriever.release()
    }
  }

  private fun scanFile(path: String, result: Result) {
    MediaScannerConnection.scanFile(
        activity!!.applicationContext,
        arrayOf(path),
        null
    ) { _, _ ->
      Log.d(TAG, "  -> scanFile success")
      result.success(null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  // ActivityAware methods
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}

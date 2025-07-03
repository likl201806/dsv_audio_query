package com.example.dsv_audio_query

import android.Manifest
import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentResolver
import android.content.ContentUris
import android.content.IntentSender
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
class DsvAudioQueryPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var resolver: ContentResolver
  private var activity: Activity? = null
  private var pendingPermResult: Result? = null
  private var pendingDeleteResult: Result? = null
  private val permissionRequestCode = 101
  private val deleteRequestCode = 102
  private val TAG = "DsvAudioQueryPlugin"

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dsv_audio_query")
    channel.setMethodCallHandler(this)
    resolver = flutterPluginBinding.applicationContext.contentResolver
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestPermission" -> {
        pendingPermResult = result
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
      "deleteFile" -> {
        val path = call.argument<String>("path")
        if (path == null) {
          result.error("INVALID_ARGUMENT", "File path cannot be null.", null)
          return
        }
        deleteFile(path, result)
      }
      "deleteSong" -> {
        // Handle numbers coming from Dart, which can be Int or Long.
        val id = (call.argument<Any>("id") as? Number)?.toLong()
        if (id == null) {
          result.error("INVALID_ARGUMENT", "Song ID cannot be null or of the wrong type.", null)
          return
        }
        deleteSong(id, result)
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
      pendingPermResult?.success(0) // granted
      pendingPermResult = null
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    if (requestCode == permissionRequestCode) {
      if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        pendingPermResult?.success(0) // granted
      } else {
        if (ActivityCompat.shouldShowRequestPermissionRationale(activity!!, permissions[0])) {
          pendingPermResult?.success(1) // denied
        } else {
          pendingPermResult?.success(2) // permanently denied
        }
      }
      pendingPermResult = null
      return true
    }
    return false
  }

  private fun querySongsFromMediaStore(result: Result) {
    Log.d(TAG, "Starting querySongsFromMediaStore.")
    val songList = mutableListOf<Map<String, Any?>>()
    val retriever = MediaMetadataRetriever()

    // Define the columns to be queried.
    val projection = arrayOf(
        MediaStore.Audio.Media._ID,
        MediaStore.Audio.Media.DATA,       // File path
        MediaStore.Audio.Media.TITLE,
        MediaStore.Audio.Media.ARTIST,
        MediaStore.Audio.Media.ALBUM
    )

    // Sort order.
    val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"
    Log.d(TAG, "Querying MediaStore.Audio without filters to get all entries.")

    try {
      resolver.query(
          MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
          projection,
          null, // No selection, get all audio entries
          null, // No selection args
          sortOrder
      )?.use { cursor -> // 'use' will automatically close the cursor
        Log.d(TAG, "Query successful. Found ${cursor.count} potential audio files in MediaStore.")
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
        val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
        val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
        val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
        val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)

        while (cursor.moveToNext()) {
          val id = cursor.getLong(idColumn)
          val filePath = cursor.getString(dataColumn)
          
          if (filePath == null) {
              Log.w(TAG, "Skipping entry with null file path. ID: $id")
              continue
          }
          Log.d(TAG, "Processing file: $filePath")

          // Primary metadata from MediaStore
          var finalTitle: String? = cursor.getString(titleColumn)
          var finalArtist: String? = cursor.getString(artistColumn)
          var finalAlbum: String? = cursor.getString(albumColumn)

          var artwork: ByteArray? = null
          var duration: Long? = null

          try {
            retriever.setDataSource(filePath)

            // Secondary metadata from the file itself (fallback)
            val retrieverTitle = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            val retrieverArtist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            val retrieverAlbum = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            
            artwork = retriever.embeddedPicture
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.let {
              duration = it.toLongOrNull()
            }
            
            // Consolidate: Use retriever data if MediaStore data is missing/invalid
            if (finalTitle.isNullOrEmpty() || finalTitle == filePath.substringAfterLast('/')) {
                finalTitle = retrieverTitle
            }
            if (finalArtist.isNullOrEmpty()) {
                finalArtist = retrieverArtist
            }
            if (finalAlbum.isNullOrEmpty()) {
                finalAlbum = retrieverAlbum
            }

            Log.d(TAG, "  -> Consolidated Metadata: Title='$finalTitle', Artist='$finalArtist', Duration=$duration")

          } catch (e: Exception) {
            Log.e(TAG, "  -> Failed to retrieve metadata for $filePath", e)
            // If retriever fails, we still have the (potentially incomplete) MediaStore data
          }

          // Filter out short audio clips and add to list
          duration?.let { currentDuration ->
            if (currentDuration >= 3000) {
                Log.d(TAG, "  -> Adding song to list: $finalTitle")
                val songMap = mapOf(
                    "id" to id,
                    "title" to finalTitle,
                    "artist" to finalArtist,
                    "album" to finalAlbum,
                    "duration" to currentDuration,
                    "data" to filePath,
                    "artwork" to artwork
                )
                songList.add(songMap)
            } else {
              Log.d(TAG, "  -> Skipping short audio file: $finalTitle, Duration: $currentDuration")
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

  private fun deleteSong(id: Long, result: MethodChannel.Result) {
    try {
      val contentUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
      val rowsDeleted = resolver.delete(contentUri, null, null)

      val success = rowsDeleted > 0
      Log.d(TAG, "Deletion result for ID $id: success=$success (mediaStoreRows=$rowsDeleted)")
      result.success(success)

    } catch (e: SecurityException) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is RecoverableSecurityException) {
        try {
            pendingDeleteResult = result // Save the result callback
            val intentSender = e.userAction.actionIntent.intentSender
            activity?.startIntentSenderForResult(intentSender, deleteRequestCode, null, 0, 0, 0, null)
        } catch (sendEx: IntentSender.SendIntentException) {
            pendingDeleteResult = null
            Log.e(TAG, "Failed to send delete intent", sendEx)
            result.error("DELETE_FAILED_SEND_INTENT", "Failed to ask for user permission.", sendEx.message)
        }
      } else {
        Log.e(TAG, "SecurityException while deleting song: ID $id.", e)
        result.error("DELETE_FAILED_PERMISSION", "Permission denied to delete song.", e.message)
      }
    }
    catch (e: Exception) {
      Log.e(TAG, "Error deleting song: ID $id", e)
      result.error("DELETE_FAILED", "An error occurred while deleting the song.", e.message)
    }
  }

  private fun deleteFile(path: String, result: MethodChannel.Result) {
    try {
      // First, try to delete the file from the MediaStore.
      // This is the modern, correct way to handle file deletions on Android.
      val where = "${MediaStore.Files.FileColumns.DATA} = ?"
      val args = arrayOf(path)
      val rowsDeleted = resolver.delete(MediaStore.Files.getContentUri("external"), where, args)

      // Second, delete the physical file.
      val file = java.io.File(path)
      var fileDeleted = false
      if (file.exists()) {
        fileDeleted = file.delete()
      }

      // The operation is successful if the MediaStore entry is gone OR the file is physically gone.
      val success = rowsDeleted > 0 || fileDeleted
      Log.d(TAG, "Deletion result for $path: success=$success (mediaStoreRows=$rowsDeleted, fileDeleted=$fileDeleted)")
      result.success(success)

    } catch (e: SecurityException) {
        Log.e(TAG, "SecurityException while deleting file: $path. Maybe a RecoverableSecurityException?", e)
        // For Android Q and above, we might need to handle RecoverableSecurityException
        // and ask the user for permission. For now, we report failure.
        result.error("DELETE_FAILED_PERMISSION", "Permission denied to delete file.", e.message)
    }
    catch (e: Exception) {
      Log.e(TAG, "Error deleting file: $path", e)
      result.error("DELETE_FAILED", "An error occurred while deleting the file.", e.message)
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
    binding.addActivityResultListener(this)
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

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
    if (requestCode == deleteRequestCode) {
        if (resultCode == Activity.RESULT_OK) {
            // User granted permission, the file is deleted by the system.
            pendingDeleteResult?.success(true)
        } else {
            // User denied permission.
            pendingDeleteResult?.success(false)
        }
        pendingDeleteResult = null // Clear the pending result
        return true
    }
    return false
  }
}

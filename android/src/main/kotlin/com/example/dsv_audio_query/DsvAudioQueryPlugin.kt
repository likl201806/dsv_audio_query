package com.example.dsv_audio_query

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
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
          querySongsFromMediaStore(result)
        } else {
          result.error("PERMISSION_DENIED", "Storage permission is denied.", null)
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
    val songList = mutableListOf<Map<String, Any?>>()
    // Define the columns to be queried.
    val projection = arrayOf(
        MediaStore.Audio.Media._ID,
        MediaStore.Audio.Media.TITLE,
        MediaStore.Audio.Media.ARTIST,
        MediaStore.Audio.Media.ALBUM,
        MediaStore.Audio.Media.DURATION,
        MediaStore.Audio.Media.DATA
    )
    // Query condition.
    val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
    // Sort order.
    val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

    try {
      resolver.query(
          MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
          projection,
          selection,
          null,
          sortOrder
      )?.use { cursor -> // 'use' will automatically close the cursor
        while (cursor.moveToNext()) {
          val songMap = mapOf(
              "id" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)),
              "title" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)),
              "artist" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)),
              "album" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)),
              "duration" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)),
              "data" to cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA))
          )
          songList.add(songMap)
        }
      }
      result.success(songList)
    } catch (e: Exception) {
      result.error("QUERY_FAILED", e.message, null)
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

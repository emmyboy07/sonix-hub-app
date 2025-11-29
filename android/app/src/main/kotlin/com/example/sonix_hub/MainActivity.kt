package com.sonixhub.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Intent
import android.provider.MediaStore
import android.net.Uri
import android.os.Environment
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sonixhub.app/gallery"
    private val SYNC_CHANNEL = "com.sonixhub.app/sync"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanGallery" -> {
                    val downloadPath = call.argument<String>("path")
                    if (downloadPath != null) {
                        scanGalleryForDownloads(downloadPath)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncWithProgress" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    if (sourcePath != null) {
                        syncFilesToDCIM(sourcePath)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                syncEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                syncEventSink = null
            }
        })
    }

    companion object {
        private var syncEventSink: EventChannel.EventSink? = null
    }

    private fun scanGalleryForDownloads(downloadPath: String) {
        try {
            // Trigger MediaStore scan for the downloads directory
            val intent = Intent("android.intent.action.MEDIA_SCANNER_SCAN_DIR")
            intent.data = Uri.fromFile(File(downloadPath))
            sendBroadcast(intent)
            
            // Also notify MediaStore of the directory change
            val mediaUri = MediaStore.Files.getContentUri("external")
            contentResolver.notifyChange(mediaUri, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun syncFilesToDCIM(sourcePath: String) {
        try {
            val sourceDir = File(sourcePath)
            if (!sourceDir.exists() || !sourceDir.isDirectory) {
                syncEventSink?.error("INVALID_PATH", "Source directory does not exist", null)
                return
            }

            // Create destination directory in DCIM
            val dcimDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), "Sonix Hub")
            if (!dcimDir.exists()) {
                dcimDir.mkdirs()
            }

            // Collect all files to copy
            val allFiles = sourceDir.walk().filter { it.isFile }.toList()
            var totalBytes = 0L
            for (file in allFiles) {
                totalBytes += file.length()
            }

            var copiedBytes = 0L
            var copiedFiles = 0

            // Copy files recursively
            for (file in allFiles) {
                try {
                    val relativePath = file.relativeTo(sourceDir).path
                    val destFile = File(dcimDir, relativePath)
                    
                    // Create parent directories if needed
                    destFile.parentFile?.mkdirs()
                    
                    // Copy file
                    file.copyTo(destFile, overwrite = true)
                    copiedBytes += file.length()
                    copiedFiles++

                    // Send progress update
                    val progress = if (totalBytes > 0) (copiedBytes.toDouble() / totalBytes) else 0.0
                    syncEventSink?.success(mapOf(
                        "progress" to progress,
                        "copiedFiles" to copiedFiles,
                        "totalFiles" to allFiles.size,
                        "copiedBytes" to copiedBytes,
                        "totalBytes" to totalBytes
                    ))
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            // Scan the new directory to make it appear in gallery apps
            val intent = Intent("android.intent.action.MEDIA_SCANNER_SCAN_DIR")
            intent.data = Uri.fromFile(dcimDir)
            sendBroadcast(intent)

            // Notify MediaStore
            val mediaUri = MediaStore.Files.getContentUri("external")
            contentResolver.notifyChange(mediaUri, null)

            // Send completion event
            syncEventSink?.success(mapOf(
                "progress" to 1.0,
                "copiedFiles" to copiedFiles,
                "totalFiles" to allFiles.size,
                "copiedBytes" to copiedBytes,
                "totalBytes" to totalBytes,
                "completed" to true
            ))
        } catch (e: Exception) {
            e.printStackTrace()
            syncEventSink?.error("SYNC_ERROR", "Error during sync: ${e.message}", null)
        }
    }
}

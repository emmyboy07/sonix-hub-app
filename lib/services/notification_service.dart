import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  static const int _downloadProgressNotificationId = 999;
  static int _notificationId = 1000;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    debugPrint('✅ 🔔 NOTIFICATION SERVICE - Initialized successfully');
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      '✅ 🔔 NOTIFICATION - User tapped notification ID: ${response.id} with payload: ${response.payload}',
    );
  }

  /// Show live download progress notification with progress bar
  Future<void> showDownloadProgress(
    String title,
    int progress,
    int total,
    double percentComplete, {
    String? posterUrl,
  }) async {
    try {
      debugPrint(
        'NOTIFICATION - Updating progress: $title - $percentComplete%',
      );

      final posterPath = await _preparePosterFile(posterUrl);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'download_channel',
            'Downloads',
            channelDescription: 'Live download progress notifications',
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: percentComplete.toInt(),
            enableVibration: false,
            playSound: false,
            largeIcon: posterPath != null
                ? FilePathAndroidBitmap(posterPath)
                : null,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        _downloadProgressNotificationId,
        'Downloading',
        '$title - ${percentComplete.toStringAsFixed(0)}%',
        platformChannelSpecifics,
        payload: 'download_progress',
      );
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - showDownloadProgress failed: $e');
    }
  }

  /// Show a download started notification
  Future<void> showDownloadStarted(String title, {String? posterUrl}) async {
    try {
      debugPrint('NOTIFICATION - Showing download started: $title');

      final posterPath = await _preparePosterFile(posterUrl);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'download_channel',
            'Downloads',
            channelDescription: 'Download progress notifications',
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: 0,
            enableVibration: false,
            playSound: true,
            largeIcon: posterPath != null
                ? FilePathAndroidBitmap(posterPath)
                : null,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        _downloadProgressNotificationId,
        'Downloading',
        title,
        platformChannelSpecifics,
        payload: 'download_started',
      );

      debugPrint(
        '✅ 🔔 NOTIFICATION - Download started notification displayed successfully',
      );
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - showDownloadStarted failed: $e');
    }
  }

  /// Show a download completion notification
  Future<void> showDownloadComplete(String title, {String? posterUrl}) async {
    try {
      debugPrint('NOTIFICATION - Showing download complete: $title');

      final posterPath = await _preparePosterFile(posterUrl);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'download_channel',
            'Downloads',
            channelDescription: 'Download progress notifications',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            enableVibration: true,
            playSound: true,
            largeIcon: posterPath != null
                ? FilePathAndroidBitmap(posterPath)
                : null,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        _notificationId,
        'Download Complete',
        title,
        platformChannelSpecifics,
        payload: 'download_complete',
      );

      debugPrint('NOTIFICATION - Download complete displayed');
      // Cancel progress notification
      await _flutterLocalNotificationsPlugin.cancel(
        _downloadProgressNotificationId,
      );
      _notificationId++;
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - showDownloadComplete failed: $e');
    }
  }

  /// Show a download failed notification
  Future<void> showDownloadFailed(
    String title,
    String error, {
    String? posterUrl,
  }) async {
    try {
      debugPrint(
        'NOTIFICATION - Showing download failed: $title - Error: $error',
      );

      final posterPath = await _preparePosterFile(posterUrl);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'download_channel',
            'Downloads',
            channelDescription: 'Download progress notifications',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            enableVibration: true,
            playSound: true,
            largeIcon: posterPath != null
                ? FilePathAndroidBitmap(posterPath)
                : null,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        _notificationId,
        'Download Failed',
        '$title - Error: $error',
        platformChannelSpecifics,
        payload: 'download_failed',
      );

      debugPrint('NOTIFICATION - Download failed displayed');
      // Cancel progress notification
      await _flutterLocalNotificationsPlugin.cancel(
        _downloadProgressNotificationId,
      );
      _notificationId++;
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - showDownloadFailed failed: $e');
    }
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    try {
      debugPrint('✅ 🔔 NOTIFICATION - Cancelling notification ID: $id');
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('✅ 🔔 NOTIFICATION - Notification cancelled successfully');
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - cancelNotification failed: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      debugPrint('✅ 🔔 NOTIFICATION - Cancelling all notifications');
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint(
        '✅ 🔔 NOTIFICATION - All notifications cancelled successfully',
      );
    } catch (e) {
      debugPrint('❌ 🔔 NOTIFICATION ERROR - cancelAllNotifications failed: $e');
    }
  }

  /// Show a release notification
  Future<void> showReleaseNotification({
    required String title,
    required String message,
    required String contentType,
    int notificationId = 6000,
    String? posterUrl,
  }) async {
    try {
      debugPrint('NOTIFICATION - Showing release: $title');

      final posterPath = await _preparePosterFile(posterUrl);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'release_channel',
            'Release Notifications',
            channelDescription:
                'Notifications for released movies and episodes',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            enableVibration: true,
            playSound: true,
            largeIcon: posterPath != null
                ? FilePathAndroidBitmap(posterPath)
                : null,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        '$contentType Released',
        '$title - $message',
        platformChannelSpecifics,
        payload: 'release_notification',
      );

      debugPrint('NOTIFICATION - Release displayed');
    } catch (e) {
      debugPrint(
        '❌ 🔔 NOTIFICATION ERROR - showReleaseNotification failed: $e',
      );
    }
  }

  /// Prepare poster file locally. Accepts network URL or local path. Returns path or null.
  Future<String?> _preparePosterFile(String? posterUrl) async {
    try {
      if (posterUrl == null || posterUrl.isEmpty) return null;
      // If it's a local file and exists, return it
      if (!posterUrl.toLowerCase().startsWith('http')) {
        final f = File(posterUrl);
        if (await f.exists()) return posterUrl;
        return null;
      }
      // Download network image to temporary file
      final resp = await http.get(Uri.parse(posterUrl));
      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          resp.bodyBytes.isNotEmpty) {
        final tmpDir = await getTemporaryDirectory();
        final fileName =
            'sonix_poster_${DateTime.now().millisecondsSinceEpoch}.png';
        final tmpPath = '${tmpDir.path}/$fileName';
        final file = File(tmpPath);
        await file.writeAsBytes(resp.bodyBytes);
        return tmpPath;
      }
    } catch (e) {
      debugPrint('NOTIFICATION - Failed preparing poster: $e');
    }
    return null;
  }
}

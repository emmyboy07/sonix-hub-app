import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandlerService {
  static final PermissionHandlerService _instance =
      PermissionHandlerService._internal();

  factory PermissionHandlerService() {
    return _instance;
  }

  PermissionHandlerService._internal();

  /// Request all required permissions on app launch
  Future<bool> requestAllPermissions() async {
    try {
      debugPrint('🔐 Requesting all required permissions...');

      // Request storage permission (Android 11+)
      final storageStatus = await Permission.manageExternalStorage.request();
      debugPrint('📁 Storage permission: $storageStatus');

      // Request notification permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      debugPrint('🔔 Notification permission: $notificationStatus');

      // Request microphone permission (for voice search)
      final microphoneStatus = await Permission.microphone.request();
      debugPrint('🎤 Microphone permission: $microphoneStatus');

      // Check if critical permissions are granted
      final hasStorage = storageStatus.isGranted || storageStatus.isDenied;
      final hasNotification =
          notificationStatus.isGranted || notificationStatus.isDenied;
      final hasMicrophone =
          microphoneStatus.isGranted || microphoneStatus.isDenied;

      if (hasStorage && hasNotification && hasMicrophone) {
        debugPrint('✅ All permissions handled');
        return true;
      }

      debugPrint('⚠️ Some permissions not granted');
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    try {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking storage permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking microphone permission: $e');
      return false;
    }
  }

  /// Open app settings if permissions are permanently denied
  Future<void> openPermissionSettings() async {
    try {
      await openAppSettings();
      debugPrint('📱 Opened app settings');
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
    }
  }
}

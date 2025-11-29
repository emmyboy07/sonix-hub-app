import 'package:flutter/foundation.dart';
import 'dart:async';
import 'release_reminder_service.dart';

/// Service that periodically checks for released content and sends notifications
class BackgroundReleaseChecker {
  static final BackgroundReleaseChecker _instance =
      BackgroundReleaseChecker._internal();
  Timer? _checkTimer;
  static const Duration _checkInterval = Duration(hours: 1);
  bool _initialized = false;

  factory BackgroundReleaseChecker() {
    return _instance;
  }

  BackgroundReleaseChecker._internal();

  /// Initialize background checker
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint(
      '✅ 🔔 BACKGROUND RELEASE CHECKER - Initializing background checker',
    );

    // Initialize the reminder service
    final reminderService = ReleaseReminderService();
    await reminderService.initialize();

    // Do an initial check
    await reminderService.checkAndNotify();

    // Set up periodic checks
    _checkTimer = Timer.periodic(_checkInterval, (timer) async {
      debugPrint('✅ 🔔 BACKGROUND RELEASE CHECKER - Running periodic check');
      await reminderService.checkAndNotify();
    });

    _initialized = true;
    debugPrint(
      '✅ 🔔 BACKGROUND RELEASE CHECKER - Initialized with ${_checkInterval.inHours} hour interval',
    );
  }

  /// Perform an immediate check
  Future<void> checkNow() async {
    debugPrint('✅ 🔔 BACKGROUND RELEASE CHECKER - Running immediate check');
    final reminderService = ReleaseReminderService();
    await reminderService.checkAndNotify();
  }

  /// Dispose of the checker
  void dispose() {
    debugPrint('✅ 🔔 BACKGROUND RELEASE CHECKER - Disposing');
    _checkTimer?.cancel();
    _initialized = false;
  }

  /// Get initialization status
  bool get isInitialized => _initialized;
}

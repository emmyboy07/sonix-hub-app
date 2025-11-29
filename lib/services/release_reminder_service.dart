import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';

/// Model to store release reminder data
class ReleaseReminder {
  final int id;
  final String title;
  final String releaseDate; // YYYY-MM-DD format
  final bool isMovie;
  final String? seasonEpisode; // For TV shows: S01:E01
  final String? posterUrl;

  ReleaseReminder({
    required this.id,
    required this.title,
    required this.releaseDate,
    required this.isMovie,
    this.seasonEpisode,
    this.posterUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'releaseDate': releaseDate,
    'isMovie': isMovie,
    'seasonEpisode': seasonEpisode,
    'posterUrl': posterUrl,
  };

  factory ReleaseReminder.fromJson(Map<String, dynamic> json) =>
      ReleaseReminder(
        id: json['id'] as int,
        title: json['title'] as String,
        releaseDate: json['releaseDate'] as String,
        isMovie: json['isMovie'] as bool,
        seasonEpisode: json['seasonEpisode'] as String?,
        posterUrl: json['posterUrl'] as String?,
      );
}

/// Service to manage release date reminders and notifications
class ReleaseReminderService {
  static final ReleaseReminderService _instance =
      ReleaseReminderService._internal();
  static const String _storageKey = 'release_reminders';
  static const int _reminderNotificationIdBase = 5000;
  late SharedPreferences _prefs;
  bool _initialized = false;

  factory ReleaseReminderService() {
    return _instance;
  }

  ReleaseReminderService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugPrint('✅ 🔔 RELEASE REMINDER SERVICE - Initialized');
  }

  /// Check if a movie/episode is unreleased
  bool isUnreleased(String releaseDate) {
    if (releaseDate.isEmpty) return false;
    try {
      final release = DateTime.parse(releaseDate);
      final now = DateTime.now();
      return release.isAfter(now);
    } catch (e) {
      debugPrint('❌ Error parsing release date: $e');
      return false;
    }
  }

  /// Get days until release
  int getDaysUntilRelease(String releaseDate) {
    if (releaseDate.isEmpty) return 0;
    try {
      final release = DateTime.parse(releaseDate);
      final now = DateTime.now();
      final difference = release.difference(now).inDays;
      return difference > 0 ? difference : 0;
    } catch (e) {
      debugPrint('❌ Error calculating days until release: $e');
      return 0;
    }
  }

  /// Format countdown message
  String getCountdownMessage(String releaseDate) {
    final daysUntil = getDaysUntilRelease(releaseDate);
    if (daysUntil == 0) return 'Releasing today!';
    if (daysUntil == 1) return 'Releasing tomorrow!';
    return 'Releasing in $daysUntil days';
  }

  /// Add a reminder for a movie/episode
  Future<void> addReminder(ReleaseReminder reminder) async {
    await initialize();
    try {
      final reminders = await getReminders();

      // Check if reminder already exists
      final existingIndex = reminders.indexWhere((r) => r.id == reminder.id);
      if (existingIndex >= 0) {
        reminders[existingIndex] = reminder;
      } else {
        reminders.add(reminder);
      }

      final json = jsonEncode(reminders.map((r) => r.toJson()).toList());
      await _prefs.setString(_storageKey, json);

      debugPrint(
        '✅ 🔔 RELEASE REMINDER SERVICE - Reminder added for: ${reminder.title}',
      );
    } catch (e) {
      debugPrint('❌ Error adding reminder: $e');
    }
  }

  /// Remove a reminder
  Future<void> removeReminder(int id) async {
    await initialize();
    try {
      final reminders = await getReminders();
      reminders.removeWhere((r) => r.id == id);

      final json = jsonEncode(reminders.map((r) => r.toJson()).toList());
      await _prefs.setString(_storageKey, json);

      debugPrint(
        '✅ 🔔 RELEASE REMINDER SERVICE - Reminder removed for ID: $id',
      );
    } catch (e) {
      debugPrint('❌ Error removing reminder: $e');
    }
  }

  /// Get all reminders
  Future<List<ReleaseReminder>> getReminders() async {
    await initialize();
    try {
      final jsonStr = _prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((item) => ReleaseReminder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting reminders: $e');
      return [];
    }
  }

  /// Check if a reminder exists for a specific item
  Future<bool> hasReminder(int id) async {
    final reminders = await getReminders();
    return reminders.any((r) => r.id == id);
  }

  /// Get reminder for a specific item
  Future<ReleaseReminder?> getReminder(int id) async {
    final reminders = await getReminders();
    try {
      return reminders.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check and send notifications for released items
  Future<void> checkAndNotify() async {
    await initialize();
    try {
      final reminders = await getReminders();
      final notificationService = NotificationService();

      for (final reminder in reminders) {
        if (!isUnreleased(reminder.releaseDate)) {
          // Item has been released, show notification
          final contentType = reminder.isMovie ? 'Movie' : 'Episode';
          final message = reminder.isMovie
              ? 'Now available!'
              : '${reminder.seasonEpisode} - Now available!';

          await notificationService.showReleaseNotification(
            title: reminder.title,
            message: message,
            contentType: contentType,
            notificationId: _reminderNotificationIdBase + reminder.id.hashCode,
            posterUrl: reminder.posterUrl,
          );

          // Remove the reminder as it's no longer needed
          await removeReminder(reminder.id);
          debugPrint(
            '✅ 🔔 RELEASE REMINDER SERVICE - Notification sent and reminder removed for: ${reminder.title}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking and notifying: $e');
    }
  }
}

# Release Date Reminder & Notification System - Implementation Guide

## Overview
This document details the implementation of a production-ready release date reminder and notification system for the Sonix Hub application. The system detects unreleased movies and episodes, displays user-friendly notifications, allows users to set reminders, and automatically sends notifications when content becomes available.

## Features Implemented

### 1. **Unreleased Content Detection**
- Automatically detects movies and episodes that haven't been released yet
- Compares release date against current date
- Works for both movies and TV episodes

### 2. **User-Friendly Toast Messages**
- When users try to play or download unreleased content, a friendly toast message is shown
- Message format: `"[Title] has not been released yet"` with `"Releasing in X days"` countdown
- Toast appears for 4 seconds with floating behavior
- Icon-based visual indicator with calendar icon

### 3. **Notification Bell Icon (Remind Me)**
- Added bell icon button next to download button on both details and episode screens
- Toggles between:
  - Empty bell (not subscribed) - white icon
  - Filled bell (subscribed) - red icon
- Users can tap to subscribe/unsubscribe from release notifications

### 4. **Persistent Reminder Storage**
- Reminders are stored in SharedPreferences
- Data structure includes:
  - Content ID
  - Content title
  - Release date (YYYY-MM-DD format)
  - Content type (movie/episode)
  - Poster URL for future use

### 5. **Background Release Checker**
- Runs periodic checks (every 1 hour) when app is running
- Initial check performed at app startup
- Automatically sends notifications when release date is reached
- Checks can also be manually triggered

### 6. **Release Notifications**
- Sends system notifications when content becomes available
- Notification includes:
  - Title: "🎬 Movie/Episode Released"
  - Content: Title + "Now available!"
  - Sound and vibration enabled
  - High priority for visibility

## File Structure

### New Files Created:
```
lib/services/
├── release_reminder_service.dart      # Core reminder management service
└── background_release_checker.dart    # Background notification checker

lib/screens/
├── details_screen.dart (modified)     # Added movie unreleased check & bell
└── episode_screen.dart (modified)     # Added episode unreleased check & bell

lib/
└── main.dart (modified)               # Initialize background checker on app start
```

### Modified Services:
```
lib/services/
└── notification_service.dart (modified)  # Added showReleaseNotification() method
```

## Usage

### For Movies (DetailsScreen):

1. **Detecting Unreleased Movies:**
   ```dart
   if (_reminderService.isUnreleased(widget.movie.releaseDate)) {
     _showUnreleasedToast(widget.movie.title);
     return; // Prevent play/download
   }
   ```

2. **Adding Reminder:**
   ```dart
   await _reminderService.addReminder(
     ReleaseReminder(
       id: widget.movie.id,
       title: widget.movie.title,
       releaseDate: widget.movie.releaseDate,
       isMovie: true,
       posterUrl: posterUrl,
     ),
   );
   ```

3. **Getting Countdown Message:**
   ```dart
   String countdown = _reminderService.getCountdownMessage(releaseDate);
   // Returns: "Releasing in 3 days" or "Releasing tomorrow!" or "Releasing today!"
   ```

### For Episodes (EpisodeScreen):

1. **Episode ID Generation:**
   ```dart
   final reminderId = '${showId}_${seasonNumber}_$episodeNumber'.hashCode.abs();
   ```

2. **Tracking Episode Reminders:**
   ```dart
   _episodeReminders[episodeNumber] = true; // Set when reminder added
   ```

3. **Displaying Unreleased Badge:**
   ```dart
   if (_reminderService.isUnreleased(ep.airDate ?? '')) {
     // Show countdown message in episode list
   }
   ```

## API Reference

### ReleaseReminderService

**Methods:**
- `initialize()` - Initialize the service with SharedPreferences
- `isUnreleased(String releaseDate)` - Check if content is unreleased
- `getDaysUntilRelease(String releaseDate)` - Get remaining days
- `getCountdownMessage(String releaseDate)` - Get user-friendly countdown text
- `addReminder(ReleaseReminder reminder)` - Add/update a reminder
- `removeReminder(int id)` - Remove a reminder
- `getReminders()` - Get all reminders
- `hasReminder(int id)` - Check if reminder exists
- `getReminder(int id)` - Get specific reminder
- `checkAndNotify()` - Check all reminders and send notifications

### ReleaseReminder Model

**Fields:**
- `int id` - Unique identifier (movieId or hashCode of episode)
- `String title` - Content title
- `String releaseDate` - Release date (YYYY-MM-DD)
- `bool isMovie` - Whether it's a movie (true) or episode (false)
- `String? seasonEpisode` - For episodes: "S01:E01" format
- `String? posterUrl` - Poster image URL

### BackgroundReleaseChecker

**Methods:**
- `initialize()` - Start background checker with 1-hour interval
- `checkNow()` - Perform immediate check
- `dispose()` - Stop background checker
- `get isInitialized` - Check if running

## Production-Ready Features

### 1. **Error Handling**
- Try-catch blocks around all critical operations
- Graceful fallbacks for missing data
- Safe null-checking throughout

### 2. **Logging**
- Comprehensive debug logging for troubleshooting
- Emoji indicators for easy log identification:
  - ✅ 🔔 - Successful operations
  - ❌ 🔔 - Errors
  - 📥 - Downloads
  - 📊 - Progress updates

### 3. **State Management**
- Uses `setState()` for UI updates
- Proper `mounted` checks before setState calls
- Efficient Future handling with FutureBuilder

### 4. **Performance**
- Background checks run at 1-hour intervals (not too frequent)
- Initial check on app startup for immediate feedback
- Efficient data storage in SharedPreferences

### 5. **User Experience**
- Toast messages are dismissible
- Clear visual feedback (icon changes)
- Non-blocking reminders (background process)
- Countdown updates in episode list

## Testing Checklist

### Manual Testing:
- [ ] Navigate to details screen of unreleased movie
- [ ] Try clicking Play button - should show toast with countdown
- [ ] Try clicking Download button - should show toast with countdown
- [ ] Click bell icon to set reminder - should turn red
- [ ] Click bell icon again - should turn white (reminder removed)
- [ ] Navigate to episode screen of TV show with unreleased episodes
- [ ] Unreleased episodes should show countdown below air date
- [ ] Try clicking unreleased episode - should show toast
- [ ] Try downloading unreleased episode - should show toast
- [ ] Click bell icon on unreleased episode - should toggle
- [ ] Close and reopen app - reminders should persist
- [ ] Wait for background checker to run (or restart app) - check notification

### Automated Testing:
```dart
// Example test for release reminder service
test('isUnreleased returns true for future dates', () {
  final futureDate = DateTime.now().add(Duration(days: 5)).toString().split(' ')[0];
  final service = ReleaseReminderService();
  expect(service.isUnreleased(futureDate), true);
});

test('getCountdownMessage returns correct format', () {
  final futureDate = DateTime.now().add(Duration(days: 3)).toString().split(' ')[0];
  final service = ReleaseReminderService();
  final message = service.getCountdownMessage(futureDate);
  expect(message.contains('3'), true);
});
```

## Configuration

### To Adjust Background Check Interval:
Edit `background_release_checker.dart`:
```dart
static const Duration _checkInterval = Duration(hours: 1); // Change to your preferred interval
```

### To Modify Notification Messages:
Edit `notification_service.dart` in the `showReleaseNotification()` method:
```dart
'🎬 $contentType Released' // Notification title
'$title - $message'        // Notification body
```

### To Customize Toast Appearance:
Edit `details_screen.dart` and `episode_screen.dart` in the `_showUnreleasedToast()` methods:
- Duration: `const Duration(seconds: 4)`
- Opacity: `withOpacity(0.9)`
- Colors and text styling

## Dependencies

All required dependencies are already in `pubspec.yaml`:
- `flutter_local_notifications: ^17.2.2` - For system notifications
- `shared_preferences: ^2.5.3` - For persistent storage
- `provider: ^6.0.0` - For state management

No additional packages needed!

## Future Enhancements

1. **Push Notifications** - Integrate Firebase Cloud Messaging for app-closed notifications
2. **Scheduled Notifications** - Use android/iOS scheduling for precise notification timing
3. **Notification Settings** - Allow users to customize notification preferences
4. **Countdown Timer UI** - Show live countdown in app header
5. **Release Calendar** - Display upcoming releases in a calendar view
6. **Email Notifications** - Optional email reminders

## Support & Troubleshooting

### Issue: Notifications not showing on app startup
**Solution:** Check that background checker is properly initialized in `main.dart`

### Issue: Reminders not persisting after app close
**Solution:** Verify SharedPreferences is being called with `await` keyword

### Issue: Toast messages overlapping
**Solution:** Check that only one toast is shown at a time by dismissing previous ones

### Issue: Background checks not running
**Solution:** Verify timer is not canceled prematurely, check logs for initialization messages

## Notes

- The system gracefully handles edge cases (missing dates, invalid formats, etc.)
- All date comparisons use UTC time for consistency
- Reminders are stored efficiently in JSON format
- The service is production-ready and can be deployed immediately
- All code follows Flutter best practices and conventions

## Version History

**v1.0.0** - Initial release
- Release date detection
- Toast notifications for unreleased content
- Reminder management system
- Background notification checker
- Bell icon UI for reminders

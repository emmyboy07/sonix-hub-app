# Release Reminder System - Quick Reference

## What Was Implemented

A **production-ready release date reminder and notification system** for unreleased movies and TV episodes in Sonix Hub.

## Key Features

### 🎬 Movie Details Screen
- **Play Button**: Checks if movie is unreleased
  - Shows friendly toast: "Movie has not been released yet • Releasing in 3 days"
  - Prevents playback if unreleased
  
- **Download Button**: Same unreleased check as Play button

- **Bell Icon (NEW)**: 
  - White bell = reminder not set
  - Red bell = reminder is set
  - Tap to toggle "Notify Me" for this movie
  - Stores reminder indefinitely until user removes it

### 📺 Episode Screen
- **Each Episode Card** displays:
  - Air date
  - Countdown message if unreleased (red text): "Releasing in 2 days"
  - Notification bell icon to set/remove reminder

- **Episode Tap**: 
  - Shows toast if unreleased: "Episode has not aired yet • Airing in 2 days"
  - Prevents playback if unreleased

- **Download Button on Episode**:
  - Same unreleased check as play button
  - Shows toast before attempting download

## How It Works

### User Flow: Setting a Reminder

1. User navigates to unreleased movie/episode
2. Clicks the bell icon (⭕ white bell = no reminder)
3. Reminder is saved to device storage
4. Bell turns red 🔴 to indicate active reminder

### User Flow: Getting Notified

1. App runs background checker every 1 hour
2. When release date is reached, system notification is sent
3. Notification title: "🎬 Movie Released" or "🎬 Episode Released"
4. Content: "[Title] - Now available!"
5. Sound & vibration enabled by default
6. Reminder is automatically cleared after notification

### Behind the Scenes

- **Release Reminder Service** (`release_reminder_service.dart`)
  - Manages all reminders (add, remove, check)
  - Stores reminders in SharedPreferences (persistent)
  - Detects unreleased content by comparing dates

- **Background Release Checker** (`background_release_checker.dart`)
  - Runs every 1 hour
  - Calls "checkAndNotify()" to send notifications
  - Initialized automatically on app startup

- **Notification Service** (updated `notification_service.dart`)
  - Sends system notifications
  - High priority, with sound and vibration

## For Developers

### Check if Content is Unreleased
```dart
final isUnreleased = _reminderService.isUnreleased(releaseDate);
if (isUnreleased) {
  _showUnreleasedToast(title);
  return;
}
```

### Set a Reminder
```dart
await _reminderService.addReminder(
  ReleaseReminder(
    id: contentId,
    title: "Movie/Episode Title",
    releaseDate: "2025-12-25", // YYYY-MM-DD
    isMovie: true, // or false for episodes
    posterUrl: posterUrl,
  ),
);
```

### Get Countdown Text
```dart
String countdown = _reminderService.getCountdownMessage(releaseDate);
// Returns: "Releasing in 3 days" or "Releasing tomorrow!" etc.
```

### Check Days Until Release
```dart
int days = _reminderService.getDaysUntilRelease(releaseDate);
```

## Files Modified/Created

### New Files:
- `lib/services/release_reminder_service.dart` - Core service (150 lines)
- `lib/services/background_release_checker.dart` - Background checker (60 lines)
- `RELEASE_REMINDER_IMPLEMENTATION.md` - Full documentation

### Modified Files:
- `lib/screens/details_screen.dart` - Added movie unreleased logic & bell icon
- `lib/screens/episode_screen.dart` - Added episode unreleased logic & bell icon
- `lib/services/notification_service.dart` - Added `showReleaseNotification()` method
- `lib/main.dart` - Initialize background checker on app startup

## Testing

### To Test Manually:

1. **Set Release Date to Tomorrow:**
   - Edit TMDB data temporarily or modify a test movie's release date

2. **Watch Toast Appear:**
   - Click Play/Download on unreleased content
   - Toast shows "Releasing tomorrow!"

3. **Set Reminder:**
   - Click bell icon
   - Icon turns red
   - Close and reopen app - reminder persists

4. **Trigger Notification:**
   - Manually restart app (triggers immediate check)
   - Or wait up to 1 hour for background checker
   - Should receive system notification

## Production Readiness Checklist

✅ Error handling - All operations wrapped in try-catch
✅ Logging - Comprehensive debug logs with emojis
✅ State management - Proper mounted checks and setState
✅ Performance - Efficient hourly checks, not CPU intensive
✅ Persistence - Uses SharedPreferences for reliable storage
✅ UI/UX - Friendly messages, clear visual feedback
✅ Edge cases - Handles null dates, invalid formats, etc.
✅ No new dependencies - Uses existing packages

## Configuration

To change background check interval, edit line 12 in `background_release_checker.dart`:
```dart
static const Duration _checkInterval = Duration(hours: 1); // Change this
```

## Known Limitations

- Background checks only run while app is in memory
- For persistent notifications when app is closed, Firebase Cloud Messaging would be needed
- Notification timing depends on when app is next opened (if changed during app closure)

## Support

For detailed implementation info, see: `RELEASE_REMINDER_IMPLEMENTATION.md`

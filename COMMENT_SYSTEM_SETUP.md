# Comment System Setup Guide

## Quick Start

The comment system is fully integrated and ready to use. Follow these steps to configure it:

## Step 1: Update API Key

Update the API key in `lib/services/comment_service.dart`:

```dart
class CommentService {
  static const String baseUrl = 'https://sonix-comment-system.vercel.app';
  static const String apiKey = 'YOUR_ACTUAL_API_KEY_HERE'; // ← Update this
```

Replace `YOUR_ACTUAL_API_KEY_HERE` with your actual mobile API key from the Sonix comment system.

## Step 2: Verify Integration

The comment system is automatically integrated in:
- ✅ `lib/screens/details_screen.dart` - Shows comment section on movie/TV show details
- ✅ `lib/providers/comments_provider.dart` - Manages comment state
- ✅ `lib/services/comment_service.dart` - API integration
- ✅ `lib/widgets/comment_section.dart` - Comment UI
- ✅ `lib/screens/comment_settings_screen.dart` - Comment settings
- ✅ `lib/screens/profile_screen.dart` - Profile integration with comment settings
- ✅ `lib/main.dart` - CommentsProvider registered

## Step 3: Build and Run

```bash
flutter pub get
flutter run
```

## Features at a Glance

### For Movies
- Browse all comments on the movie details page
- Post new comments
- Reply to comments from other users
- Like/unlike comments
- Report inappropriate comments

### For TV Shows
- Browse all series comments
- Post comments for the entire series
- Reply and like comments
- Report comments

### Settings
- Go to Profile → Comment Settings to customize your display name
- Default name is "Anonymous"
- Maximum 30 characters for custom name
- Name persists across app sessions

## API Details

### Endpoints

**Get Comments**
```
GET https://sonix-comment-system.vercel.app/api/comments/movie/{tmdbId}
GET https://sonix-comment-system.vercel.app/api/comments/tv/{tmdbId}
```

**Post Comment**
```
POST https://sonix-comment-system.vercel.app/api/comments/movie/{tmdbId}
POST https://sonix-comment-system.vercel.app/api/comments/tv/{tmdbId}

Body:
{
  "user_name": "Your Name",
  "comment_text": "Your comment",
  "parent_comment_id": "optional-uuid" // for replies
}
```

**Like Comment**
```
POST https://sonix-comment-system.vercel.app/api/likes

Body:
{
  "comment_id": "uuid",
  "user_name": "Your Name"
}
```

**Report Comment**
```
POST https://sonix-comment-system.vercel.app/api/reports

Body:
{
  "comment_id": "uuid",
  "reporter_name": "Your Name",
  "reason": "spam|harassment|inappropriate|other"
}
```

### Authentication

All requests require:
```
Header: x-mobile-api-key: YOUR_API_KEY
Header: Content-Type: application/json
```

## Important Notes

### Not Implemented (By Design)
- Episode-specific comments
- Season-specific comments
- Users can only comment at movie/series level

### User Names
- Default: "Anonymous"
- Users can customize in Settings
- Name is displayed with each comment

### Rate Limiting
- 100 requests per minute per IP
- Returns 429 status if exceeded
- App displays user-friendly error message

## Troubleshooting

### Comments Section Not Appearing
1. Check that `CommentSection` widget is imported in `details_screen.dart`
2. Verify `CommentsProvider` is registered in `main.dart`
3. Rebuild the app

### API Errors
1. Verify API key is correct in `comment_service.dart`
2. Check internet connection
3. Verify API endpoint is accessible
4. Check API key has necessary permissions

### User Name Not Saving
1. Check SharedPreferences is accessible
2. Verify name field is not empty
3. Restart the app

### Comments Not Loading
1. Check TMDB ID is correct
2. Verify internet connection
3. Check API status at https://sonix-comment-system.vercel.app

## Configuration Options (Future)

Consider moving API key to secure configuration:

### Option 1: Environment Variables
```bash
export SONIX_COMMENT_API_KEY="your_key_here"
```

### Option 2: Config File
Create `lib/config/comment_config.dart`:
```dart
class CommentConfig {
  static const String apiKey = String.fromEnvironment(
    'SONIX_COMMENT_API_KEY',
    defaultValue: 'your_mobile_api_key_here',
  );
}
```

### Option 3: Secure Storage
```dart
// Use flutter_secure_storage package
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CommentService {
  static const storage = FlutterSecureStorage();
  
  static Future<String> getApiKey() async {
    return await storage.read(key: 'comment_api_key') ?? 'default_key';
  }
}
```

## Support

For issues or questions:
1. Check `COMMENT_SYSTEM_GUIDE.md` for detailed documentation
2. Review error messages in the app
3. Check API logs at https://sonix-comment-system.vercel.app

---

**Version:** 1.0.0  
**Status:** ✅ Ready to Deploy

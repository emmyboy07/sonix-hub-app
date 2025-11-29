# Comment System Implementation Guide - Sonix Hub

## Overview
A complete comment system has been implemented for the Sonix Hub app that allows users to comment on movies and TV series, reply to comments, like comments, and report inappropriate content.

## Architecture

### Components

#### 1. **Models** (`lib/models/comment.dart`)
- `Comment` - Represents a comment with nested replies
- `LikeStatus` - Tracks like count and user's like status

#### 2. **Services** (`lib/services/comment_service.dart`)
- `CommentService` - API integration layer handling:
  - Fetching comments for movies/TV shows
  - Posting comments on movies/TV shows
  - Toggling likes on comments
  - Reporting comments
  - Error handling with proper status codes

#### 3. **Provider** (`lib/providers/comments_provider.dart`)
- `CommentsProvider` - State management using ChangeNotifier
  - Manages comment list state
  - Handles user name persistence in SharedPreferences
  - Manages comment posting and replies
  - Tracks like statuses
  - Handles error states

#### 4. **UI Components**
- `CommentSection` (`lib/widgets/comment_section.dart`) - Main comment widget with:
  - Comment input field with reply functionality
  - Comments list with nested replies
  - Like and report buttons
  - User name display
  
- `CommentSettingsScreen` (`lib/screens/comment_settings_screen.dart`) - Settings screen to:
  - Set custom comment display name
  - Preview how comments will appear
  - Reset to anonymous

## API Integration

### Base URL
```
https://sonix-comment-system.vercel.app/
```

### Endpoints Implemented

#### Get Comments for Movies
```
GET /api/comments/movie/{tmdbId}
```

#### Get Comments for TV Shows
```
GET /api/comments/tv/{tmdbId}
```

#### Post Comment on Movies
```
POST /api/comments/movie/{tmdbId}
Request Body:
{
  "user_name": "John Doe",
  "comment_text": "Great movie! 🎬",
  "parent_comment_id": "uuid" // Optional, for replies
}
```

#### Post Comment on TV Shows
```
POST /api/comments/tv/{tmdbId}
Request Body:
{
  "user_name": "John Doe",
  "comment_text": "Amazing series! 🎬",
  "parent_comment_id": "uuid" // Optional, for replies
}
```

#### Toggle Like
```
POST /api/likes
Request Body:
{
  "comment_id": "uuid-of-comment",
  "user_name": "John Doe"
}
```

#### Get Like Status
```
GET /api/likes/{comment_id}?user_name=John%20Doe
```

#### Report Comment
```
POST /api/reports
Request Body:
{
  "comment_id": "uuid-of-comment",
  "reporter_name": "John Doe",
  "reason": "spam" // Options: spam, harassment, inappropriate, other
}
```

### API Key
All requests require the mobile API key header:
```
x-mobile-api-key: your_mobile_api_key_here
```

**Note:** The API key is currently set to `your_mobile_api_key_here` in `lib/services/comment_service.dart`. Update this in `CommentService` class:
```dart
static const String apiKey = 'your_mobile_api_key_here';
```

## Features

### ✅ Implemented Features

1. **Read Comments**
   - Fetch all comments for a movie/TV show
   - Display comments with user names and timestamps
   - Support for nested replies

2. **Write Comments**
   - Post comments on movies and TV shows
   - Reply to existing comments with parent comment ID
   - Default user name is "Anonymous"

3. **Like/Unlike**
   - Toggle like on any comment
   - Display current like count
   - Track user's like status

4. **Report Comments**
   - Report inappropriate comments
   - Multiple report reasons: spam, harassment, inappropriate, other
   - User-friendly report dialog

5. **User Name Settings**
   - Default user name is "Anonymous"
   - Change custom display name in Comment Settings
   - Name persists using SharedPreferences
   - Name is displayed before each comment

6. **Nested Replies**
   - Show/hide reply threads with expand/collapse
   - Reply count display
   - Full comment threading support

7. **Time Formatting**
   - "just now" for recent comments
   - "Xm ago" for minutes
   - "Xh ago" for hours
   - "Xd ago" for days
   - Full date for older comments

### ❌ Intentionally Excluded Features

- Episode-specific comments (only movie/series level)
- Season-specific comments (only movie/series level)
- User profiles or authentication
- Comment editing/deletion

## UI/UX Design

### Comment Section Layout
```
┌─────────────────────────────────┐
│         Comments                │
├─────────────────────────────────┤
│ [Text input for comment]         │
│              [Post Button]       │
│ Commenting as: Anonymous        │
├─────────────────────────────────┤
│ User Name          just now      │
│ Great movie! 🎬                  │
│ ❤ 5    ↩ Reply    🚩 Report     │
│                                  │
│ ▶ Show 2 replies                │
├─────────────────────────────────┤
│ User Name 2        1h ago        │
│ Amazing!                         │
│ ❤ 2    ↩ Reply                  │
└─────────────────────────────────┘
```

### Integration Points

**1. Details Screen** (`lib/screens/details_screen.dart`)
- Comment section added before "Recommended" section
- Shows after all movie/TV show info
- Scrollable with other page content

**2. Profile Screen** (`lib/screens/profile_screen.dart`)
- New "Comment Settings" option
- Allows users to customize comment display name

**3. Main App** (`lib/main.dart`)
- `CommentsProvider` registered in MultiProvider
- Available globally throughout the app

## Usage Guide

### For Users

1. **View Comments**
   - Scroll to the Comments section on movie/TV show details page
   - Comments load automatically

2. **Post a Comment**
   - Enter text in the comment field
   - Click "Post"
   - Your comment appears at the top of the list

3. **Reply to a Comment**
   - Click "Reply" button on any comment
   - Notice "Replying to [User Name]" indicator appears
   - Enter your reply text
   - Click "Post"

4. **Like a Comment**
   - Click the heart icon on any comment
   - Heart fills and like count increases

5. **Report a Comment**
   - Click the flag icon
   - Select reason from dialog
   - Report submitted

6. **Change Comment Name**
   - Go to Profile → Comment Settings
   - Enter custom display name (max 30 characters)
   - Click "Save Display Name"
   - Or reset to "Anonymous"

### For Developers

#### Fetch Comments
```dart
final comments = await CommentService.getMovieComments(550); // Movie ID
final tvComments = await CommentService.getTVComments(1399); // TV Show ID
```

#### Post Comment
```dart
final comment = await CommentService.postMovieComment(
  tmdbId: 550,
  userName: 'John Doe',
  commentText: 'Amazing movie!',
  parentCommentId: 'optional-parent-id', // For replies
);
```

#### Use Provider
```dart
final provider = context.read<CommentsProvider>();

// Set user name
await provider.setUserName('Custom Name');

// Fetch comments
await provider.fetchMovieComments(movieId);

// Post comment
await provider.postMovieComment(
  tmdbId: movieId,
  commentText: 'Great movie!',
);

// Toggle like
await provider.toggleLike(commentId);

// Report comment
await provider.reportComment(
  commentId: commentId,
  reason: 'spam',
);
```

## State Management

### CommentsProvider State
- `_comments` - List of comments for current media
- `_userName` - Current user's display name
- `_isLoading` - Loading state for API calls
- `_errorMessage` - Last error message
- `_likeStatuses` - Map of comment IDs to like statuses

### Lifecycle
1. **Initialization** - User name loaded from SharedPreferences
2. **Navigation** - Comments fetched when Comment Section widget initializes
3. **Interaction** - Comments posted/liked/reported via API
4. **Persistence** - Only user name is persisted locally

## Error Handling

### HTTP Status Codes
- `200/201` - Success
- `400` - Bad request (validation error)
- `401` - Unauthorized (invalid API key)
- `404` - Not found (no comments yet)
- `429` - Rate limited (100 requests/minute per IP)
- `500` - Server error

### User Feedback
- Toast messages for success/failure
- Error descriptions in SnackBars
- Empty state message when no comments
- Loading spinner during fetch

## Security Considerations

1. **API Key** - Store securely (currently placeholder)
   - TODO: Move to environment variables or secure config
   - Never commit actual API keys

2. **User Input** - Validated before sending
   - Comment text trimmed
   - Name length limited to 30 characters
   - Reason validation for reports

3. **Data Handling**
   - No sensitive user data stored locally
   - API responses parsed safely
   - Error messages don't expose sensitive info

## Performance Optimization

1. **Lazy Loading**
   - Comments load on demand when section becomes visible
   - Nested replies loaded with parent comment

2. **Caching**
   - Like statuses cached in `_likeStatuses` map
   - Reduces redundant API calls

3. **Pagination** (Future Enhancement)
   - Currently loads all comments
   - Can implement client-side pagination if needed

4. **Memory Management**
   - Controllers properly disposed
   - Listeners cleaned up on widget disposal

## Future Enhancements

1. **Pagination** - Implement pagination for large comment lists
2. **Comment Editing** - Allow users to edit their own comments
3. **Comment Deletion** - Allow users to delete their own comments
4. **Mentions** - @mention other users in comments
5. **Emoji Picker** - Quick emoji insertion
6. **Rich Text** - Markdown or formatted text support
7. **Search** - Search comments by text
8. **Sorting** - Sort by newest/oldest/most liked
9. **User Profiles** - Click username to view profile
10. **Notifications** - Notify users of replies to their comments

## Troubleshooting

### Comments Not Loading
- Check internet connection
- Verify TMDB ID is correct
- Check API key in CommentService
- Check API endpoint availability

### Can't Post Comment
- Ensure comment text is not empty
- Check internet connection
- Verify user name is set
- Check for rate limiting (429 status)

### Name Not Saving
- Check SharedPreferences permissions
- Verify name is not empty
- Restart app to reload

### Likes Not Working
- Ensure comment ID is valid
- Check internet connection
- Verify user name is set

## File Structure
```
lib/
├── models/
│   └── comment.dart
├── services/
│   └── comment_service.dart
├── providers/
│   └── comments_provider.dart
├── widgets/
│   └── comment_section.dart
├── screens/
│   ├── details_screen.dart (modified)
│   ├── profile_screen.dart (modified)
│   └── comment_settings_screen.dart
└── main.dart (modified)
```

## Testing Checklist

- [ ] Comments load for movies
- [ ] Comments load for TV shows
- [ ] Can post a comment
- [ ] Can reply to a comment
- [ ] Replies show nested properly
- [ ] Can like/unlike comments
- [ ] Can report comments
- [ ] User name saves and persists
- [ ] Can change user name from settings
- [ ] Comments show correct timestamps
- [ ] Error messages display properly
- [ ] App handles no comments gracefully
- [ ] Handles API errors gracefully
- [ ] Rate limiting handled (429)

---

**Last Updated:** November 25, 2025  
**Version:** 1.0.0  
**Status:** ✅ Implementation Complete

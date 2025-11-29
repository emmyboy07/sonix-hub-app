# Android/Kotlin Integration Reference

This document provides reference examples for integrating the Sonix comment API with native Android code, if needed.

## OkHttp Implementation

### CommentApiClient.kt

```kotlin
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Callback
import okhttp3.Call
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException

class CommentApiClient {
    private val client = OkHttpClient()
    private val baseUrl = "https://sonix-comment-system.vercel.app"
    private val apiKey = "your_mobile_api_key" // TODO: Store securely in Keystore
    
    // Get comments for a movie
    fun getMovieComments(
        tmdbId: Int,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val url = "$baseUrl/api/comments/movie/$tmdbId"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val comments = response.body?.string()
                    onSuccess(comments ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Get comments for a TV show
    fun getTVComments(
        tmdbId: Int,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val url = "$baseUrl/api/comments/tv/$tmdbId"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val comments = response.body?.string()
                    onSuccess(comments ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Post a comment on a movie
    fun postMovieComment(
        tmdbId: Int,
        userName: String,
        commentText: String,
        parentCommentId: String? = null,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val json = JSONObject().apply {
            put("user_name", userName)
            put("comment_text", commentText)
            parentCommentId?.let { put("parent_comment_id", it) }
        }
        
        val body = json.toString()
            .toRequestBody("application/json".toMediaType())
        
        val url = "$baseUrl/api/comments/movie/$tmdbId"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val comment = response.body?.string()
                    onSuccess(comment ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Post a comment on a TV show
    fun postTVComment(
        tmdbId: Int,
        userName: String,
        commentText: String,
        parentCommentId: String? = null,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val json = JSONObject().apply {
            put("user_name", userName)
            put("comment_text", commentText)
            parentCommentId?.let { put("parent_comment_id", it) }
        }
        
        val body = json.toString()
            .toRequestBody("application/json".toMediaType())
        
        val url = "$baseUrl/api/comments/tv/$tmdbId"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val comment = response.body?.string()
                    onSuccess(comment ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Toggle like on a comment
    fun toggleLike(
        commentId: String,
        userName: String,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val json = JSONObject().apply {
            put("comment_id", commentId)
            put("user_name", userName)
        }
        
        val body = json.toString()
            .toRequestBody("application/json".toMediaType())
        
        val url = "$baseUrl/api/likes"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val result = response.body?.string()
                    onSuccess(result ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Get like status for a comment
    fun getLikeStatus(
        commentId: String,
        userName: String,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val encodedName = java.net.URLEncoder.encode(userName, "UTF-8")
        val url = "$baseUrl/api/likes/$commentId?user_name=$encodedName"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    val status = response.body?.string()
                    onSuccess(status ?: "")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
    
    // Report a comment
    fun reportComment(
        commentId: String,
        reporterName: String,
        reason: String, // spam, harassment, inappropriate, other
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val json = JSONObject().apply {
            put("comment_id", commentId)
            put("reporter_name", reporterName)
            put("reason", reason)
        }
        
        val body = json.toString()
            .toRequestBody("application/json".toMediaType())
        
        val url = "$baseUrl/api/reports"
        val request = Request.Builder()
            .url(url)
            .addHeader("x-mobile-api-key", apiKey)
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    onSuccess("Comment reported successfully")
                } else {
                    onError("Error: ${response.code}")
                }
                response.close()
            }
            
            override fun onFailure(call: Call, e: IOException) {
                onError(e.message ?: "Unknown error")
            }
        })
    }
}
```

## Secure Storage Implementation

### SecureCommentApiClient.kt

```kotlin
import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureCommentApiClient(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    
    private val sharedPreferences: SharedPreferences = 
        EncryptedSharedPreferences.create(
            context,
            "comment_api_secret",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    
    // Store API key securely
    fun storeApiKey(apiKey: String) {
        sharedPreferences.edit().apply {
            putString("api_key", apiKey)
            apply()
        }
    }
    
    // Retrieve API key securely
    fun getApiKey(): String {
        return sharedPreferences.getString("api_key", "") ?: ""
    }
    
    // Store user name for comments
    fun storeCommentUserName(userName: String) {
        sharedPreferences.edit().apply {
            putString("comment_user_name", userName)
            apply()
        }
    }
    
    // Retrieve user name
    fun getCommentUserName(): String {
        return sharedPreferences.getString("comment_user_name", "Anonymous") ?: "Anonymous"
    }
}
```

## Usage Example

```kotlin
class MainActivity : AppCompatActivity() {
    private lateinit var apiClient: CommentApiClient
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        apiClient = CommentApiClient()
        
        // Fetch movie comments
        apiClient.getMovieComments(550,
            onSuccess = { comments ->
                println("Comments: $comments")
            },
            onError = { error ->
                println("Error: $error")
            }
        )
    }
}
```

## Dependency Setup

Add to `build.gradle`:

```gradle
dependencies {
    // OkHttp
    implementation 'com.squareup.okhttp3:okhttp:4.11.0'
    
    // JSON
    implementation 'org.json:json:20231013'
    
    // Secure Storage (if using SecureCommentApiClient)
    implementation 'androidx.security:security-crypto:1.1.0-alpha06'
}
```

## Error Handling

### Status Codes

| Code | Meaning | Handling |
|------|---------|----------|
| 200 | Success | Process response |
| 201 | Created | Process new comment |
| 400 | Bad Request | Show validation error |
| 401 | Unauthorized | Check API key |
| 404 | Not Found | No comments yet |
| 429 | Rate Limited | Show message, retry later |
| 500 | Server Error | Show generic error |

### Example Error Handling

```kotlin
private fun handleApiError(code: Int): String {
    return when (code) {
        400 -> "Invalid request. Please check your input."
        401 -> "API key is invalid or expired."
        404 -> "No comments found for this content."
        429 -> "Too many requests. Please wait a moment and try again."
        500 -> "Server error. Please try again later."
        else -> "An unexpected error occurred."
    }
}
```

## Rate Limiting

The API has a rate limit of 100 requests per minute per IP address.

```kotlin
private fun shouldRetry(code: Int): Boolean {
    return code == 429
}

private suspend fun retryWithBackoff(
    block: suspend () -> Response,
    maxRetries: Int = 3
): Response? {
    repeat(maxRetries) { attempt ->
        try {
            val response = block()
            if (response.code != 429) {
                return response
            }
            // Exponential backoff
            delay(1000L * (2 pow attempt))
        } catch (e: Exception) {
            // Handle exception
        }
    }
    return null
}

private infix fun Int.pow(exp: Int): Long {
    return (1..exp).fold(1L) { acc, _ -> acc * this }
}
```

---

**Note:** This is reference material for native Android/Kotlin implementations. The Sonix Hub app uses Flutter, which is a cross-platform framework with its own HTTP client implementation documented in the main `COMMENT_SYSTEM_GUIDE.md`.

**Version:** 1.0.0  
**Last Updated:** November 25, 2025

/// API Configuration for Sonix Hub
class ApiConfig {
  // TMDB API
  static const String tmdbApiKey = 'YOUR_TMDB_API_KEY';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // MovieBox API
  static const String movieboxBaseUrl =
      'https://moviebox.ph/wefeed-h5-bff/web/subject';

  /// Proxy Download API - Replace with your actual backend URL
  ///
  /// Deployment Options:
  /// 1. Node.js/Express + Vercel: https://your-vercel-project.vercel.app/api/proxy
  /// 2. Node.js/Express + Heroku: https://your-heroku-app.herokuapp.com/api/proxy/download
  /// 3. Dart Shelf Server: https://your-server.com:8080/api/proxy/download
  /// 4. Firebase Cloud Functions: https://us-central1-your-project.cloudfunctions.net/proxyDownload
  /// 5. AWS Lambda: https://your-api-gateway.execute-api.region.amazonaws.com/prod/proxy/download
  ///
  /// Update this URL to your deployed backend endpoint
  static const String proxyDownloadBaseUrl =
      'https://your-backend-api.com/api/proxy/download';

  /// Alternative: Use different proxy endpoints for different regions/servers
  static String getProxyDownloadUrl({
    String baseUrl = proxyDownloadBaseUrl,
    required String videoUrl,
  }) {
    final encodedUrl = Uri.encodeComponent(videoUrl);
    return '$baseUrl?url=$encodedUrl';
  }

  /// Get alternative proxy URLs (useful if primary is down)
  static List<String> getAlternativeProxyUrls({required String videoUrl}) {
    final encodedUrl = Uri.encodeComponent(videoUrl);
    return [
      '$proxyDownloadBaseUrl?url=$encodedUrl',
      // Add backup proxy URLs here if needed
      // 'https://backup-proxy-1.com/api/proxy/download?url=$encodedUrl',
      // 'https://backup-proxy-2.com/api/proxy/download?url=$encodedUrl',
    ];
  }
}

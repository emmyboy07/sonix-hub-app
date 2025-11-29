import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef DownloadProgressCallback =
    void Function(
      double progress,
      int bytesReceived,
      int totalBytes,
      int speedBytesPerSecond,
      Duration eta,
    );

/// Direct proxy download without a server
/// Makes HTTP requests with browser headers to bypass 403 restrictions
Future<bool> proxyDownload({
  required String videoUrl,
  required String filePath,
  required DownloadProgressCallback onProgress,
}) async {
  debugPrint('🌐 Starting proxy download: $videoUrl');
  debugPrint('📁 Saving to: $filePath');

  final headers = {
    'Referer':
        'https://fmoviesunblocked.net/spa/videoPlayPage/movies/the-amateur-uD0mYexJSs3?id=2908887247384723616&type=/movie/detail',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'en-GB,en;q=0.9,fa-IR;q=0.8,fa;q=0.7,en-US;q=0.6',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };

  try {
    debugPrint('🔗 Making HTTP request with proxy headers...');
    final request = http.Request('GET', Uri.parse(videoUrl));
    request.headers.addAll(headers);

    final response = await request.send();
    debugPrint('📊 Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('❌ Download failed with status: ${response.statusCode}');
      return false;
    }

    debugPrint('✅ Response OK, starting download stream...');
    final contentLength = response.contentLength ?? 0;
    debugPrint('📦 Content length: $contentLength bytes');

    var received = 0;
    final file = File(filePath);
    final sink = file.openWrite();
    final startTime = DateTime.now();
    int lastProgressUpdate = DateTime.now().millisecondsSinceEpoch;

    await response.stream
        .listen(
          (chunk) {
            received += chunk.length;
            final progress = contentLength > 0 ? received / contentLength : 0.0;

            // Update progress at most every 500ms to avoid excessive updates
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressUpdate >= 500 || progress >= 1.0) {
              lastProgressUpdate = now;

              // Calculate speed and ETA
              final elapsedSeconds = DateTime.now()
                  .difference(startTime)
                  .inSeconds;
              final speedBytesPerSecond = elapsedSeconds > 0
                  ? (received / elapsedSeconds).toInt()
                  : 0;

              Duration eta = Duration.zero;
              if (speedBytesPerSecond > 0 && contentLength > 0) {
                final remainingBytes = contentLength - received;
                final remainingSeconds = remainingBytes ~/ speedBytesPerSecond;
                eta = Duration(seconds: remainingSeconds);
              }

              onProgress(
                progress,
                received,
                contentLength,
                speedBytesPerSecond,
                eta,
              );
            }

            sink.add(chunk);
          },
          onError: (e) {
            debugPrint('❌ Stream error: $e');
            sink.close();
            file.deleteSync();
          },
        )
        .asFuture();

    await sink.close();
    debugPrint('✅ Download completed: $filePath ($received bytes written)');
    return true;
  } catch (e) {
    debugPrint('❌ Download error: $e');
    debugPrint('❌ Stack trace: ${StackTrace.current}');
    return false;
  }
}

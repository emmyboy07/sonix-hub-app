import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionInfo {
  final String latestVersion;
  final String minRequiredVersion;
  final bool forceUpdate;
  final String title;
  final String message;
  final String apkDownloadUrl;
  final String iosAppStoreUrl;
  final List<String> changelog;
  final String releaseNotesUrl;
  final String releaseDate;
  final bool criticalFix;

  VersionInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.apkDownloadUrl,
    required this.iosAppStoreUrl,
    this.changelog = const [],
    this.releaseNotesUrl = '',
    this.releaseDate = '',
    this.criticalFix = false,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    // Parse changelog array
    List<String> changelog = [];
    if (json['changelog'] is List) {
      changelog = (json['changelog'] as List).cast<String>();
    }

    return VersionInfo(
      latestVersion: json['latest_version'] as String? ?? '0.0.0',
      minRequiredVersion: json['min_required_version'] as String? ?? '0.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      title: json['title'] as String? ?? 'Update Available',
      message: json['message'] as String? ?? 'A new version is available.',
      apkDownloadUrl: json['apk_download_url'] as String? ?? '',
      iosAppStoreUrl: json['ios_app_store_url'] as String? ?? '',
      changelog: changelog,
      releaseNotesUrl: json['release_notes_url'] as String? ?? '',
      releaseDate: json['release_date'] as String? ?? '',
      criticalFix: json['critical_fix'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static const String _versionJsonUrl =
      'https://raw.githubusercontent.com/emmyboy07/sonix-hub/main/.github/version.json';
  static const Duration _timeout = Duration(seconds: 10);

  // Set to true for local testing, false for production
  static const bool _useTestMode = false;

  /// Mock version info for testing
  static VersionInfo _getMockVersionInfo() {
    return VersionInfo(
      latestVersion: '12.1.0',
      minRequiredVersion: '1.0.0',
      forceUpdate: true,
      title: '🧪 Test Update Available',
      message:
          'This is a TEST update modal.\n\nClick "Update Now" to test opening the browser.',
      apkDownloadUrl: 'https://github.com/emmyboy07/sonix-hub/releases',
      iosAppStoreUrl: 'https://apps.apple.com/app/sonix-hub/id123456789',
      changelog: [
        '✨ Real-time genre display',
        '📅 Updated release date format',
        '🔄 In-app force update system',
        '⚡ Performance improvements',
      ],
      releaseDate: '2025-11-29',
      criticalFix: true,
    );
  }

  /// Fetch version info from GitHub or mock (for testing)
  static Future<VersionInfo?> fetchVersionInfo() async {
    // Return mock data for local testing
    if (_useTestMode) {
      print('🧪 Using TEST MODE - returning mock version info');
      return _getMockVersionInfo();
    }

    try {
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(
            _timeout,
            onTimeout: () {
              throw TimeoutException('Failed to fetch version info');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VersionInfo.fromJson(data);
      } else {
        print('❌ Failed to fetch version info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching version info: $e');
      return null;
    }
  }

  /// Check if update is needed
  static Future<UpdateCheckResult?> checkForUpdate() async {
    try {
      final versionInfo = await fetchVersionInfo();
      if (versionInfo == null) {
        print('⚠️ Could not fetch version info');
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('📱 Current version: $currentVersion');
      print('🌐 Latest version: ${versionInfo.latestVersion}');
      print('📋 Min required: ${versionInfo.minRequiredVersion}');

      final needsUpdate = _isVersionLess(
        currentVersion,
        versionInfo.latestVersion,
      );
      final isForceUpdate =
          versionInfo.forceUpdate &&
          _isVersionLess(currentVersion, versionInfo.minRequiredVersion);

      return UpdateCheckResult(
        versionInfo: versionInfo,
        needsUpdate: needsUpdate,
        isForceUpdate: isForceUpdate,
      );
    } catch (e) {
      print('❌ Error checking for update: $e');
      return null;
    }
  }

  /// Compare semantic versions (e.g., "1.2.3" vs "1.2.4")
  static bool _isVersionLess(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (currentParts.length < latestParts.length) {
        currentParts.add(0);
      }
      while (latestParts.length < currentParts.length) {
        latestParts.add(0);
      }

      // Compare each part
      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < latestParts[i]) return true;
        if (currentParts[i] > latestParts[i]) return false;
      }
      return false; // versions are equal
    } catch (e) {
      print('❌ Error comparing versions: $e');
      return false;
    }
  }

  /// Open APK download URL in Chrome (or default browser)
  static Future<void> openApkDownload(String apkUrl) async {
    try {
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch URL: $apkUrl');
      }
    } catch (e) {
      print('❌ Error opening APK URL: $e');
    }
  }

  /// Open iOS App Store URL
  static Future<void> openAppStore(String iosUrl) async {
    try {
      final uri = Uri.parse(iosUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch URL: $iosUrl');
      }
    } catch (e) {
      print('❌ Error opening App Store URL: $e');
    }
  }
}

class UpdateCheckResult {
  final VersionInfo versionInfo;
  final bool needsUpdate;
  final bool isForceUpdate;

  UpdateCheckResult({
    required this.versionInfo,
    required this.needsUpdate,
    required this.isForceUpdate,
  });
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

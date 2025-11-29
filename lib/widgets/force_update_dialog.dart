import 'package:flutter/material.dart';
import 'dart:io';
import '../config/theme.dart';
import '../services/update_service.dart';

class ForceUpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final bool isForceUpdate;

  const ForceUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.isForceUpdate,
  });

  void _handleUpdate(BuildContext context) {
    if (Platform.isAndroid) {
      UpdateService.openApkDownload(versionInfo.apkDownloadUrl);
    } else if (Platform.isIOS) {
      UpdateService.openAppStore(versionInfo.iosAppStoreUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForceUpdate, // Prevent back navigation if forced
      child: Dialog(
        backgroundColor: Colors.transparent,
        barrierDismissible:
            !isForceUpdate, // Prevent tapping outside to close if forced
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.mediumBlack,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    versionInfo.criticalFix
                        ? Icons.warning_amber_rounded
                        : Icons.system_update,
                    color: AppTheme.primaryRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  versionInfo.title,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  versionInfo.message,
                  style: TextStyle(
                    color: AppTheme.lightGray,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Changelog (if available)
                if (versionInfo.changelog.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBlack,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "What's New",
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...versionInfo.changelog.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              item,
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Version info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBlack,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Version ${versionInfo.latestVersion}',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 12,
                        ),
                      ),
                      if (versionInfo.releaseDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Released: ${versionInfo.releaseDate}',
                          style: TextStyle(
                            color: AppTheme.lightGray.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (versionInfo.criticalFix) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 14,
                              color: AppTheme.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Critical Update',
                              style: TextStyle(
                                color: AppTheme.primaryRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Later button (only if optional update)
                    if (!isForceUpdate)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.mediumBlack,
                              border: Border.all(
                                color: AppTheme.lightGray.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Later',
                                style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!isForceUpdate) const SizedBox(width: 12),

                    // Update button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _handleUpdate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Update Now',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Force update info
                if (isForceUpdate) ...[
                  const SizedBox(height: 16),
                  Text(
                    'This is a required update',
                    style: TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

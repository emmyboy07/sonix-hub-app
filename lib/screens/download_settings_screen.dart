import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/download_manager.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  late Future<bool> _autoDownloadSubtitlesFuture;
  late Future<int> _totalDownloadSizeFuture;
  final _downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _autoDownloadSubtitlesFuture = _downloadManager.getAutoDownloadSubtitles();
    _totalDownloadSizeFuture = _downloadManager.getTotalDownloadedSize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: Text('Download Settings'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-download subtitles setting
            Text(
              'Subtitle Settings',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: _autoDownloadSubtitlesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryRed,
                      ),
                    ),
                  );
                }

                final autoDownload = snapshot.data ?? false;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumBlack,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-download Subtitles',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Automatically download available subtitles when downloading movies and episodes',
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: autoDownload,
                        onChanged: (value) async {
                          await _downloadManager.setAutoDownloadSubtitles(
                            value,
                          );
                          setState(() {
                            _autoDownloadSubtitlesFuture = _downloadManager
                                .getAutoDownloadSubtitles();
                          });
                        },
                        activeThumbColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Storage information
            Text(
              'Storage',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: _totalDownloadSizeFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryRed,
                      ),
                    ),
                  );
                }

                final totalSize = snapshot.data ?? 0;
                final formattedSize = _downloadManager.formatBytes(totalSize);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumBlack,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downloaded Content Size',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedSize,
                            style: TextStyle(
                              color: AppTheme.primaryRed,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.storage, color: AppTheme.primaryRed, size: 32),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.lightGray.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.lightGray, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Downloads are stored in: /storage/emulated/0/Android/media/com.sonixhub.app/downloads',
                      style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

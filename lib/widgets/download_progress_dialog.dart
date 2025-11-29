import 'package:flutter/material.dart';
import '../config/theme.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String title;
  final Function(bool) onProgressUpdate; // Called with completion status
  final Function() onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.title,
    required this.onProgressUpdate,
    required this.onCancel,
  });

  @override
  State<DownloadProgressDialog> createState() => DownloadProgressDialogState();
}

class DownloadProgressDialogState extends State<DownloadProgressDialog> {
  String _status = 'Preparing download...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
  }

  void updateProgress(String message, double progress) {
    if (mounted) {
      setState(() {
        _status = message;
        _progress = progress.clamp(0.0, 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.mediumBlack,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Downloading',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.darkBlack,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onCancel,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumBlack,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: AppTheme.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

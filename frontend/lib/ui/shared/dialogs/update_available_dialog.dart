import 'dart:io' show Platform;
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';

/// Displays a rich, modern dialog notifying the user of an available app update,
/// providing in-app background downloading with real-time progress and direct installation.
Future<void> showUpdateAvailableDialog(
  BuildContext context, {
  required AppUpdateInfo updateInfo,
  VoidCallback? onDismiss,
}) async {
  try {
    SoundService.playInfo();
    HapticService.info();
  } catch (_) {}

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _UpdateDialogWidget(
        updateInfo: updateInfo,
        onDismiss: onDismiss,
      );
    },
  );
}

class _UpdateDialogWidget extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const _UpdateDialogWidget({
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;
  String? _errorMessage;
  CancelToken? _cancelToken;

  final bool _isWindows = !kIsWeb && Platform.isWindows;
  final bool _isAndroid = !kIsWeb && Platform.isAndroid;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startInAppDownload() async {
    final info = widget.updateInfo;
    final downloadUrl = info.downloadUrl;

    if (downloadUrl == null || downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
      setState(() {
        _errorMessage = 'No direct download package available for your platform. Please use the web release link.';
      });
      return;
    }

    final defaultExt = _isWindows ? '.exe' : (_isAndroid ? '.apk' : '');
    final fallbackFileName = 'TIS_RMS_${info.latestVersion}$defaultExt';
    final assetFileName = info.assetName ?? fallbackFileName;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _cancelToken = CancelToken();
    });

    try {
      final savedPath = await AppUpdateService.downloadUpdateFile(
        downloadUrl: downloadUrl,
        fileName: assetFileName,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
            if (total > 0) {
              _downloadProgress = (received / total).clamp(0.0, 1.0);
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _downloadedFilePath = savedPath;
      });

      try {
        SoundService.playSuccess();
        HapticService.success();
      } catch (_) {}

      // Automatically trigger installer launch
      await _triggerInstall(savedPath);
    } catch (e) {
      if (!mounted) return;
      if (_cancelToken?.isCancelled == true) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        return;
      }
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
    });
  }

  Future<void> _triggerInstall([String? customPath]) async {
    final path = customPath ?? _downloadedFilePath;
    if (path == null) return;

    setState(() {
      _isInstalling = true;
      _errorMessage = null;
    });

    try {
      await AppUpdateService.recordPendingUpdateVersion(widget.updateInfo.latestVersion);
      await AppUpdateService.installDownloadedUpdate(
        path,
        targetVersion: widget.updateInfo.latestVersion,
      );
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    final currentVer = 'v${widget.updateInfo.currentVersion.replaceFirst(RegExp(r'^[vV]'), '')}';
    final latestVer = widget.updateInfo.latestVersion.startsWith('v')
        ? widget.updateInfo.latestVersion
        : 'v${widget.updateInfo.latestVersion}';
    final assetLabel = widget.updateInfo.assetName ??
        (_isWindows ? 'TIS_RMS_Client_Setup.exe' : 'TIS_RMS_Universal.apk');

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      elevation: 8,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 20 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: isMobile ? 580 : 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Minimalist Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.updateInfo.releaseTitle.isNotEmpty
                              ? widget.updateInfo.releaseTitle
                              : 'Update Available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          assetLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!_isDownloading)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : Colors.grey.shade500,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDismiss?.call();
                      },
                    ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),

            // ── Body ────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Minimal Version Difference Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            currentVer,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : Colors.grey.shade400,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              latestVer,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'New version',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Download Progress / State Box ─────────────────
                    if (_isDownloading) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Downloading update...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _downloadProgress > 0 ? _downloadProgress : null,
                                minHeight: 6,
                                backgroundColor:
                                    isDark ? Colors.black26 : Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _totalBytes > 0
                                  ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}'
                                  : 'Connecting...',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (_downloadedFilePath != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isWindows
                                    ? 'Download complete. Installer launched.'
                                    : 'Download complete. Tap below to install.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Error message banner
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // What's New
                    Text(
                      'What\'s New',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: _isDownloading ? 120 : 180,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          widget.updateInfo.releaseNotes.isNotEmpty
                              ? widget.updateInfo.releaseNotes
                              : 'Bug fixes, performance improvements, and stability updates.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Buttons ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
              ),
              child: _buildActionButtons(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    if (_isDownloading) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Download'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_downloadedFilePath != null) {
      return Row(
        children: [
          Expanded(
            flex: 4,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDismiss?.call();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: ElevatedButton.icon(
              onPressed: _isInstalling ? null : () => _triggerInstall(),
              icon: _isInstalling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.install_mobile_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
              label: Text(
                _isInstalling
                    ? 'Launching...'
                    : (_isAndroid ? 'Install with Package Installer' : 'Launch Installer'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Remind me later button
        Expanded(
          flex: 4,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDismiss?.call();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Later',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Update Now button (Direct in-app download)
        Expanded(
          flex: 6,
          child: ElevatedButton.icon(
            onPressed: _startInAppDownload,
            icon: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Download Update',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

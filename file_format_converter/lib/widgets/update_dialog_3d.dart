import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/app_update_service.dart';

class UpdateDialog3D extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog3D({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog3D(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog3D> createState() => _UpdateDialog3DState();
}

class _UpdateDialog3DState extends State<UpdateDialog3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _rocketCtrl;
  final _service = AppUpdateService();

  bool _isDownloading = false;
  double _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _rocketCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rocketCtrl.dispose();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    if (_downloadedFilePath != null) {
      // Already downloaded, trigger install
      await _service.installApk(
        _downloadedFilePath!,
        fallbackUrl: widget.updateInfo.downloadUrl,
      );
      return;
    }

    if (widget.updateInfo.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download URL is not available.')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    final path = await _service.downloadApk(
      widget.updateInfo.downloadUrl,
      onProgress: (p, received, total) {
        if (mounted) {
          setState(() {
            _progress = p;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
    );

    if (mounted) {
      if (path != null) {
        setState(() {
          _isDownloading = false;
          _downloadedFilePath = path;
        });

        // Trigger install immediately
        await _service.installApk(
          path,
          fallbackUrl: widget.updateInfo.downloadUrl,
        );
      } else {
        setState(() => _isDownloading = false);
        // Fallback: open URL in external browser
        await _service.installApk('', fallbackUrl: widget.updateInfo.downloadUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;

    return PopScope(
      canPop: !widget.updateInfo.forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D animated floating rocket badge
              AnimatedBuilder(
                animation: _rocketCtrl,
                builder: (_, __) {
                  final float = math.sin(_rocketCtrl.value * math.pi) * 6;
                  final tilt = math.cos(_rocketCtrl.value * math.pi) * 0.08;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..translateByDouble(0.0, -float, 0.0, 1.0)
                      ..rotateZ(tilt),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.proStart, AppColors.proEnd],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.proStart.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Title + Version pill
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Update Available!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v${widget.updateInfo.latestVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Release notes container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.updateInfo.releaseNotes.isNotEmpty
                          ? widget.updateInfo.releaseNotes
                          : 'Performance improvements and bug fixes.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Download progress if active
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        '${AppUtils.formatFileSize(_receivedBytes)} / ${AppUtils.formatFileSize(_totalBytes)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Action buttons
              Row(
                children: [
                  if (!widget.updateInfo.forceUpdate && !_isDownloading) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isDownloading ? null : _startUpdate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _downloadedFilePath != null
                                ? Icons.install_mobile_rounded
                                : Icons.download_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _downloadedFilePath != null
                                ? 'Install Now'
                                : (_isDownloading ? 'Downloading...' : 'Update Now'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

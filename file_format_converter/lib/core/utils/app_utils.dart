import 'package:intl/intl.dart';

class AppUtils {
  AppUtils._();

  /// Format file size in human-readable form
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format a [DateTime] to a friendly string
  static String formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(dateOnly).inDays;

    final timeStr = DateFormat('h:mm a').format(dt);
    if (diff == 0) return 'Today, $timeStr';
    if (diff == 1) return 'Yesterday, $timeStr';
    return DateFormat('MMM d, y').format(dt);
  }

  /// Format seconds to HH:MM:SS countdown string
  static String formatCountdown(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Return seconds until midnight (daily reset)
  static int secondsUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now).inSeconds;
  }

  /// Extension from file name
  static String fileExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// File name without extension
  static String fileBaseName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(0, dotIndex) : name;
  }

  /// File name with extension
  static String fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }
}
